import os
import re
import time

import mne
import numpy as np
from autoreject import AutoReject
from scipy.signal import welch

# -------------------------------------------------
# COMEÇO: cronómetro do script
# -------------------------------------------------
t0 = time.perf_counter()

try:

    def estimate_dirtiness(raw_eeg, epoch_len=2.0, k_mad=6.0):
        """% de epochs extremos com base em p2p robusto (µV)."""
        epochs = mne.make_fixed_length_epochs(
            raw_eeg, duration=epoch_len, preload=True, reject_by_annotation=False
        )

        data = epochs.get_data() * 1e6  # µV
        p2p = data.max(axis=2) - data.min(axis=2)  # (n_epochs, n_ch)
        p2p_epoch = np.median(p2p, axis=1)  # robusto por epoch

        med = np.median(p2p_epoch)
        mad = np.median(np.abs(p2p_epoch - med)) + 1e-12
        thr = med + k_mad * mad

        pct_extreme = float(np.mean(p2p_epoch > thr))
        return pct_extreme, {
            "p2p_med": float(med),
            "p2p_thr": float(thr),
            "n_epochs": len(epochs),
        }

    def base_grid_from_Q(Q):
        """Grid base por nº de canais (Q)."""
        if Q <= 20:
            n_interpolate = [1, 2, 3, min(4, Q)]
            consensus = [0.6, 0.8, 0.9]
        elif Q <= 35:
            n_interpolate = [2, 4, 6, 8, min(10, Q)]
            consensus = [0.6, 0.7, 0.8, 0.9]
        else:
            n_interpolate = [4, 8, 12, 16]
            consensus = [0.6, 0.7, 0.8]
        return n_interpolate, consensus

    def adapt_grid_with_dirtiness(Q, n_interpolate, consensus, pct_extreme):
        """
        Adapta grids consoante o nível de sujidade.
        Mantém filosofia: AutoReject escolhe por CV dentro do grid.
        """
        # Classificar o nível de contaminação estimado.
        if pct_extreme < 0.05:
            level = "clean"
        elif pct_extreme < 0.20:
            level = "medium"
        else:
            level = "dirty"

        # Limitar a grelha em função do número de canais.
        cap_by_Q = Q if Q <= 20 else (16 if Q <= 35 else 32)

        n_int = list(n_interpolate)
        cons = list(consensus)

        if level == "clean":
            # Reduzir a agressividade e o custo computacional.
            n_int = sorted(set(n_int[: max(2, len(n_int) // 2)]))
            # Manter valores de consenso moderados.
            cons = [0.6, 0.8] if 0.8 in cons else [0.6, max(cons)]
        elif level == "dirty":
            # Alargar n_interpolate para permitir mais reparações.
            extra = []
            for frac in [0.25, 0.35]:
                extra.append(min(cap_by_Q, max(1, int(round(frac * Q)))))
            n_int = sorted(set(n_int + extra))
            # Incluir um consenso mais elevado para sinais contaminados.
            cons = sorted(set(cons + [0.9]))
            if Q <= 20:
                # Restringir a interpolação quando existem poucos canais.
                n_int = [x for x in n_int if x <= 4] or [1, 2, 4]

        # Garantir limites e ordem.
        n_int = [x for x in n_int if 1 <= x <= cap_by_Q]
        cons = [c for c in cons if 0.5 <= c <= 1.0]

        return level, n_int, cons

    def configure_autoreject_auto(raw_eeg, random_state=42, epoch_len=2.0):
        Q = len(mne.pick_types(raw_eeg.info, eeg=True, meg=False, exclude="bads"))
        pct_ext, stats = estimate_dirtiness(raw_eeg, epoch_len=epoch_len)

        n_int_base, cons_base = base_grid_from_Q(Q)
        level, n_int, cons = adapt_grid_with_dirtiness(
            Q, n_int_base, cons_base, pct_ext
        )

        ar = AutoReject(n_interpolate=n_int, consensus=cons, random_state=random_state)

        meta = {
            "Q": Q,
            "dirtiness_level": level,
            "pct_extreme_epochs": pct_ext,
            **stats,
            "n_interpolate_grid": n_int,
            "consensus_grid": cons,
        }
        return ar, meta

    def find_epoch_duration_that_tiles_raw(
        raw, target_sec=2.0, min_sec=0.5, max_sec=5.0
    ):
        """
        Escolhe um duration (segundos) tal que:
        n_samp_epoch divide n_times exatamente (sem cauda)
        e que fique o mais perto possível de target_sec,
        respeitando min_sec e max_sec.
        """
        sfreq = raw.info["sfreq"]
        n_times = raw.n_times

        target_samp = int(round(target_sec * sfreq))
        min_samp = int(np.ceil(min_sec * sfreq))
        max_samp = int(np.floor(max_sec * sfreq))

        # procurar divisores de n_times dentro do intervalo
        candidates = []
        for n_samp in range(min_samp, max_samp + 1):
            if n_times % n_samp == 0:
                candidates.append(n_samp)

        if not candidates:
            raise ValueError(
                "Não foi encontrada uma duração de época que divida exatamente "
                f"as {n_times} amostras entre {min_sec} e {max_sec} segundos."
            )

        best = min(candidates, key=lambda s: abs(s - target_samp))
        return best / sfreq

    def metrics_to_rows(metrics_out, signal_name="Sinal"):
        """
        Converte o resultado de avaliar_metricas_3_grupos() em linhas de tabela.
        """
        rows = []

        # Ocular: quatro rácios antes e quatro depois.
        ocular = metrics_out.get("ocular", {})
        if "orig" in ocular and "filt" in ocular:
            for key in ["Delta/Beta", "Delta/Alpha", "Theta/Beta", "Theta/Alpha"]:
                rows.append(
                    {
                        "Grupo": "Ocular (Frontal)",
                        "Métrica": key,
                        "Antes": ocular["orig"].get(key, np.nan),
                        "Depois": ocular["filt"].get(key, np.nan),
                    }
                )

        # Muscular: quatro métricas antes e quatro depois.
        muscle = metrics_out.get("muscle", {})
        if "orig" in muscle and "filt" in muscle:
            for key in ["Beta/Gamma", "Gamma/Alpha", "Power>35Hz", "OneOverF_slope"]:
                rows.append(
                    {
                        "Grupo": "Muscular (Temporal)",
                        "Métrica": key,
                        "Antes": muscle["orig"].get(key, np.nan),
                        "Depois": muscle["filt"].get(key, np.nan),
                    }
                )

        # Ruído de linha.
        ln = metrics_out.get("line_noise", {})
        for key, label in [
            ("orig_50", "Line Noise 50Hz"),
            ("orig_60", "Line Noise 60Hz"),
        ]:
            if key in ln:
                # Emparelhar cada valor original com o valor filtrado.
                hz = "50" if "50" in key else "60"
                rows.append(
                    {
                        "Grupo": "Ruído de Linha",
                        "Métrica": label,
                        "Antes": ln.get(f"orig_{hz}", np.nan),
                        "Depois": ln.get(f"filt_{hz}", np.nan),
                    }
                )

        # Adicionar a variação entre os dois sinais.
        for r in rows:
            a, b = r["Antes"], r["Depois"]
            r["Delta (Depois-Antes)"] = (
                (b - a) if (np.isfinite(a) and np.isfinite(b)) else np.nan
            )
            r["Sinal"] = signal_name

        return rows

    def export_metrics_pdf(
        rows,
        filename="relatorio_metricas.pdf",
        out_dir="outputs/metrics/autoreject",
        title="Relatório de Métricas (Antes vs Depois)",
    ):
        """
        Guarda o PDF em out_dir/filename. Cria a pasta se não existir.
        """
        os.makedirs(out_dir, exist_ok=True)
        out_pdf_path = os.path.join(out_dir, filename)

        from reportlab.lib import colors
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import getSampleStyleSheet
        from reportlab.lib.units import cm
        from reportlab.platypus import (
            Paragraph,
            SimpleDocTemplate,
            Spacer,
            Table,
            TableStyle,
        )

        def _fmt(x, nd=4):
            if x is None or (isinstance(x, float) and np.isnan(x)):
                return "N/A"
            x = float(x)
            if abs(x) < 1e-6:
                return f"{x:.3e}"
            return f"{x:.{nd}f}"

        doc = SimpleDocTemplate(
            out_pdf_path,
            pagesize=A4,
            leftMargin=2 * cm,
            rightMargin=2 * cm,
            topMargin=1.8 * cm,
            bottomMargin=1.8 * cm,
        )

        styles = getSampleStyleSheet()
        story = [Paragraph(title, styles["Title"]), Spacer(1, 12)]

        headers = ["Sinal", "Grupo", "Métrica", "Antes", "Depois", "Delta"]
        data = [headers]

        for r in rows:
            data.append(
                [
                    str(r.get("Sinal", "")),
                    str(r.get("Grupo", "")),
                    str(r.get("Métrica", "")),
                    _fmt(r.get("Antes", np.nan)),
                    _fmt(r.get("Depois", np.nan)),
                    _fmt(r.get("Delta (Depois-Antes)", np.nan)),
                ]
            )

        col_widths = [2.2 * cm, 3.2 * cm, 5.4 * cm, 2.2 * cm, 2.2 * cm, 2.2 * cm]
        table = Table(data, colWidths=col_widths, repeatRows=1)

        table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1F3A5F")),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    ("FONTSIZE", (0, 0), (-1, 0), 10),
                    ("ALIGN", (3, 1), (-1, -1), "CENTER"),
                    ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                    ("GRID", (0, 0), (-1, -1), 0.3, colors.grey),
                    ("FONTSIZE", (0, 1), (-1, -1), 9),
                    (
                        "ROWBACKGROUNDS",
                        (0, 1),
                        (-1, -1),
                        [colors.whitesmoke, colors.lightgrey],
                    ),
                    ("LEFTPADDING", (0, 0), (-1, -1), 6),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                    ("TOPPADDING", (0, 0), (-1, -1), 4),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
                ]
            )
        )

        story.append(table)
        doc.build(story)

        return out_pdf_path

    # ---------------------------
    # Métricas / Avaliação
    # ---------------------------

    def compute_bsi_pre_ictal(
        raw, left_chs, right_chs, t_pre_start, t_pre_end, t_ictal_start, t_ictal_end
    ):

        raw_pre = raw.copy().crop(t_pre_start, t_pre_end)
        raw_ictal = raw.copy().crop(t_ictal_start, t_ictal_end)

        bsi_pre = compute_bsi_over_time(raw_pre, left_chs, right_chs)
        bsi_ictal = compute_bsi_over_time(raw_ictal, left_chs, right_chs)

        return {
            "bsi_pre_mean": np.nanmean(bsi_pre),
            "bsi_ictal_mean": np.nanmean(bsi_ictal),
            "delta_bsi": np.nanmean(bsi_ictal) - np.nanmean(bsi_pre),
        }

    def compute_bsi_over_time(raw, left_chs, right_chs):
        """
        Calcula BSI para todos os segmentos de 10s.
        Retorna lista de BSI por segmento.
        """
        segments = get_10s_segments(raw)
        bsi_values = []

        for seg in segments:
            bsi = compute_bsi_segment(seg, left_chs, right_chs)
            bsi_values.append(bsi)

        return np.array(bsi_values)

    def compute_bsi_segment(segment, left_chs, right_chs, fmin=0.5, fmax=30):
        """
        Calcula BSI espectral (0.5–30 Hz) para um segmento de 10s.
        """

        sfreq = segment.info["sfreq"]

        def mean_psd(ch_list):
            psds = []
            for ch in ch_list:
                data = segment.get_data(picks=[ch])[0]
                freqs, psd = welch(data, fs=sfreq, nperseg=int(sfreq * 2))
                mask = (freqs >= fmin) & (freqs <= fmax)
                psds.append(psd[mask])
            return np.mean(psds, axis=0), freqs[mask]

        P_L, _ = mean_psd(left_chs)
        P_R, _ = mean_psd(right_chs)

        numerator = np.sum(np.abs(P_R - P_L))
        denominator = np.sum(P_R + P_L)

        if denominator == 0:
            return np.nan

        return numerator / denominator

    def get_10s_segments(raw):
        """
        Divide o sinal contínuo em segmentos não sobrepostos de 10 segundos.
        Retorna lista de Raw objects.
        """
        duration = raw.times[-1]

        segments = []
        t = 0

        while t + 10 <= duration:
            seg = raw.copy().crop(tmin=t, tmax=t + 10)
            segments.append(seg)
            t += 10

        return segments

    def symmetric_temporal_pairs(
        raw, x_thr=0.07, y_abs_max=0.05, exclude="bads", n_pairs=None
    ):
        """
        Garante mesmo nº de canais temporais L/R.
        Se n_pairs=None: usa o máximo possível (min(len(L),len(R))).
        Se n_pairs int: usa os n_pairs mais "laterais" (maior |x|).
        """
        montage = raw.get_montage()
        if montage is None:
            raise RuntimeError(
                "raw não tem montage/dig; não dá para inferir temporais por posição."
            )
        ch_pos = montage.get_positions().get("ch_pos", {})

        L, R = temporal_by_x_threshold(
            raw, x_thr=x_thr, y_abs_max=y_abs_max, exclude=exclude
        )
        if len(L) == 0 or len(R) == 0:
            return [], []

        # Ordenar por lateralidade, começando pelo maior valor de |x|.
        L_sorted = sorted(L, key=lambda ch: abs(ch_pos[ch][0]), reverse=True)
        R_sorted = sorted(R, key=lambda ch: abs(ch_pos[ch][0]), reverse=True)

        n = min(len(L_sorted), len(R_sorted))
        if n_pairs is not None:
            n = min(n, int(n_pairs))

        return L_sorted[:n], R_sorted[:n]

    def temporal_by_x_threshold(raw, x_thr=0.07, y_abs_max=0.05, exclude="bads"):
        montage = raw.get_montage()
        if montage is None:
            raise RuntimeError(
                "raw não tem montage/dig; não dá para inferir temporais por posição."
            )

        ch_pos = montage.get_positions().get("ch_pos", {})
        if not ch_pos:
            raise RuntimeError("montage não tem 'ch_pos' (posições de canais).")

        picks = mne.pick_types(
            raw.info, eeg=True, meg=False, eog=False, exclude=exclude
        )
        eeg_names = [raw.ch_names[i] for i in picks]

        temporal_left = []
        temporal_right = []

        for ch in eeg_names:
            if ch not in ch_pos:
                continue
            x, y, z = ch_pos[ch]

            if y_abs_max is not None and abs(y) > y_abs_max:
                continue

            if x <= -x_thr:
                temporal_left.append(ch)
            elif x >= x_thr:
                temporal_right.append(ch)

        return temporal_left, temporal_right

    def frontal_by_y_threshold(raw, y_thr=0.07):
        montage = raw.get_montage()
        ch_pos = montage.get_positions()["ch_pos"]
        picks = mne.pick_types(raw.info, eeg=True, meg=False, exclude=[])
        eeg_names = [raw.ch_names[i] for i in picks]
        frontal = [ch for ch in eeg_names if ch in ch_pos and ch_pos[ch][1] >= y_thr]
        return frontal

    def normalize_1020_eeg_name(ch_name: str) -> str:
        """
        Normaliza nomes EEG para compatibilizar com a standard_1020.
        - Remove prefixo "EEG " se existir.
        - Normaliza Fc -> FC e Cp -> CP (Fc1->FC1, Cp6->CP6, etc.).
        - Mantém o resto como está (Fp1, F3, Cz, etc.).
        """
        name = ch_name.strip()

        # Remover o prefixo típico.
        if name.upper().startswith("EEG "):
            name = name[4:].strip()

        # Aplicar as normalizações específicas deste conjunto de dados.
        name = re.sub(r"^Fc(\d+)$", r"FC\1", name)
        name = re.sub(r"^Cp(\d+)$", r"CP\1", name)

        return name

    # -----------------------------
    # Bandas
    # -----------------------------
    def get_default_bands():
        return {
            "Delta": (0.5, 4),
            "Theta": (4, 8),
            "Alpha": (8, 13),
            "Beta": (13, 30),
            "Gamma": (30, 45),
        }

    # -----------------------------
    # PSD Welch + bandpower
    # -----------------------------
    def compute_psd_welch(x, sfreq, nperseg=None):
        if nperseg is None:
            # Usar dois segundos por omissão.
            nperseg = int(round(sfreq * 2.0))
        freqs, psd = welch(x, fs=sfreq, nperseg=nperseg)
        return freqs, psd

    def bandpower_from_psd(freqs, psd, fmin, fmax):
        mask = (freqs >= fmin) & (freqs <= fmax)
        if not np.any(mask):
            return np.nan
        return float(np.trapz(psd[mask], freqs[mask]))

    # ============================================================
    # 1) MÉTRICAS OCULARES (frontais) — 8 valores
    # ============================================================
    def ocular_metrics_frontal(
        raw_orig, raw_filt, y_thr=0.07, bandas=None, nperseg=None
    ):
        """
        Retorna 8 valores:
        - orig: mean Delta/Beta, Delta/Alpha, Theta/Beta, Theta/Alpha
        - filt: mean Delta/Beta, Delta/Alpha, Theta/Beta, Theta/Alpha
        Cálculo apenas em canais frontais (por posição y>=y_thr).
        """
        if bandas is None:
            bandas = get_default_bands()

        def ratios_on_raw(raw):
            frontal_chs = frontal_by_y_threshold(raw, y_thr=y_thr)
            if len(frontal_chs) == 0:
                return {
                    "Delta/Beta": np.nan,
                    "Delta/Alpha": np.nan,
                    "Theta/Beta": np.nan,
                    "Theta/Alpha": np.nan,
                }

            sfreq = raw.info["sfreq"]
            vals = {
                k: []
                for k in ["Delta/Beta", "Delta/Alpha", "Theta/Beta", "Theta/Alpha"]
            }

            for ch in frontal_chs:
                x = raw.get_data(picks=[ch])[0]
                freqs, psd = compute_psd_welch(x, sfreq, nperseg=nperseg)

                P_delta = bandpower_from_psd(freqs, psd, *bandas["Delta"])
                P_theta = bandpower_from_psd(freqs, psd, *bandas["Theta"])
                P_alpha = bandpower_from_psd(freqs, psd, *bandas["Alpha"])
                P_beta = bandpower_from_psd(freqs, psd, *bandas["Beta"])

                vals["Delta/Beta"].append(
                    P_delta / P_beta
                    if (np.isfinite(P_delta) and np.isfinite(P_beta) and P_beta > 0)
                    else np.nan
                )
                vals["Delta/Alpha"].append(
                    P_delta / P_alpha
                    if (np.isfinite(P_delta) and np.isfinite(P_alpha) and P_alpha > 0)
                    else np.nan
                )
                vals["Theta/Beta"].append(
                    P_theta / P_beta
                    if (np.isfinite(P_theta) and np.isfinite(P_beta) and P_beta > 0)
                    else np.nan
                )
                vals["Theta/Alpha"].append(
                    P_theta / P_alpha
                    if (np.isfinite(P_theta) and np.isfinite(P_alpha) and P_alpha > 0)
                    else np.nan
                )

            return {k: float(np.nanmean(vals[k])) for k in vals}

        orig = ratios_on_raw(raw_orig)
        filt = ratios_on_raw(raw_filt)

        return {
            "orig": orig,
            "filt": filt,
            "values_8": [
                orig["Delta/Beta"],
                orig["Delta/Alpha"],
                orig["Theta/Beta"],
                orig["Theta/Alpha"],
                filt["Delta/Beta"],
                filt["Delta/Alpha"],
                filt["Theta/Beta"],
                filt["Theta/Alpha"],
            ],
        }

    # ============================================================
    # 2) MÉTRICAS MUSCULARES (temporais) — 8 valores
    # ============================================================
    def muscle_metrics_temporal(
        raw_orig,
        raw_filt,
        x_thr=0.07,
        y_abs_max=0.05,
        n_pairs=None,
        bandas=None,
        nperseg=None,
        hf_min=35.0,
        slope_fmin=10.0,
        slope_fmax=80.0,
        exclude_bands=((49, 51), (59, 61)),
    ):
        """
        Retorna 8 valores (temporais):
        - orig: mean Beta/Gamma, Gamma/Alpha, Power>35Hz, 1/f slope
        - filt: mean Beta/Gamma, Gamma/Alpha, Power>35Hz, 1/f slope

        Usa temporais simétricos (mesmo nº L/R) escolhidos por posição.
        """
        if bandas is None:
            bandas = get_default_bands()

        def compute_on_raw(raw):
            L, R = symmetric_temporal_pairs(
                raw, x_thr=x_thr, y_abs_max=y_abs_max, n_pairs=n_pairs
            )
            temporal = L + R
            if len(temporal) == 0:
                return {
                    "Beta/Gamma": np.nan,
                    "Gamma/Alpha": np.nan,
                    "Power>35Hz": np.nan,
                    "OneOverF_slope": np.nan,
                    "temporal_left": L,
                    "temporal_right": R,
                }

            sfreq = raw.info["sfreq"]
            bg_list, ga_list, hf_list, slope_list = [], [], [], []

            for ch in temporal:
                x = raw.get_data(picks=[ch])[0]
                freqs, psd = compute_psd_welch(x, sfreq, nperseg=nperseg)

                # Potência por banda.
                P_alpha = bandpower_from_psd(freqs, psd, *bandas["Alpha"])
                P_beta = bandpower_from_psd(freqs, psd, *bandas["Beta"])
                P_gamma = bandpower_from_psd(freqs, psd, *bandas["Gamma"])

                # Rácios entre bandas.
                bg_list.append(
                    P_beta / P_gamma
                    if (np.isfinite(P_beta) and np.isfinite(P_gamma) and P_gamma > 0)
                    else np.nan
                )
                ga_list.append(
                    P_gamma / P_alpha
                    if (np.isfinite(P_gamma) and np.isfinite(P_alpha) and P_alpha > 0)
                    else np.nan
                )

                # Potência de alta frequência acima de 35 Hz.
                hf = bandpower_from_psd(freqs, psd, hf_min, freqs[-1])
                hf_list.append(hf)

                # Declive 1/f por ajuste log-log.
                mask = (freqs >= slope_fmin) & (freqs <= slope_fmax)
                for a, b in exclude_bands:
                    mask &= ~((freqs >= a) & (freqs <= b))

                f = freqs[mask]
                p = psd[mask]
                valid = (f > 0) & (p > 0)
                f = f[valid]
                p = p[valid]

                if len(f) < 10:
                    slope_list.append(np.nan)
                else:
                    a, _ = np.polyfit(np.log10(f), np.log10(p), 1)
                    slope_list.append(float(a))

            return {
                "Beta/Gamma": float(np.nanmean(bg_list)),
                "Gamma/Alpha": float(np.nanmean(ga_list)),
                "Power>35Hz": float(np.nanmean(hf_list)),
                "OneOverF_slope": float(np.nanmean(slope_list)),
                "temporal_left": L,
                "temporal_right": R,
            }

        orig = compute_on_raw(raw_orig)
        filt = compute_on_raw(raw_filt)

        return {
            "orig": orig,
            "filt": filt,
            "values_8": [
                orig["Beta/Gamma"],
                orig["Gamma/Alpha"],
                orig["Power>35Hz"],
                orig["OneOverF_slope"],
                filt["Beta/Gamma"],
                filt["Gamma/Alpha"],
                filt["Power>35Hz"],
                filt["OneOverF_slope"],
            ],
        }

    # ============================================================
    # 3) RUÍDO DE LINHA (50/60) — antes/depois
    # ============================================================
    def line_noise_metric(
        raw, line_freq=50.0, bw=1.0, guard=2.0, picks=None, nperseg=None
    ):
        """
        Métrica = Potência na banda [f-bw, f+bw] / Potência nas bandas adjacentes.
        Adjacent = [f-guard-2bw, f-guard] U [f+guard, f+guard+2bw]
        """
        sfreq = raw.info["sfreq"]
        if picks is None:
            picks = mne.pick_types(raw.info, eeg=True, meg=False, exclude="bads")

        data = raw.get_data(picks=picks)

        num_list, den_list = [], []
        for i in range(data.shape[0]):
            freqs, psd = compute_psd_welch(data[i], sfreq, nperseg=nperseg)

            num = bandpower_from_psd(freqs, psd, line_freq - bw, line_freq + bw)
            den1 = bandpower_from_psd(
                freqs, psd, line_freq - guard - 2 * bw, line_freq - guard
            )
            den2 = bandpower_from_psd(
                freqs, psd, line_freq + guard, line_freq + guard + 2 * bw
            )
            den = den1 + den2

            num_list.append(num)
            den_list.append(den)

        num_m = float(np.nanmean(num_list))
        den_m = float(np.nanmean(den_list))
        ratio = (
            (num_m / den_m)
            if (np.isfinite(num_m) and np.isfinite(den_m) and den_m > 0)
            else np.nan
        )

        return {
            "line_freq": line_freq,
            "ratio_mean": float(ratio),
            "num_mean": num_m,
            "den_mean": den_m,
        }

    def line_noise_metrics(raw_orig, raw_filt, bw=1.0, guard=2.0, nperseg=None):
        picks_eeg = mne.pick_types(raw_orig.info, eeg=True, meg=False, exclude="bads")

        ln50_0 = line_noise_metric(
            raw_orig,
            line_freq=50.0,
            bw=bw,
            guard=guard,
            picks=picks_eeg,
            nperseg=nperseg,
        )
        ln50_1 = line_noise_metric(
            raw_filt,
            line_freq=50.0,
            bw=bw,
            guard=guard,
            picks=picks_eeg,
            nperseg=nperseg,
        )

        ln60_0 = line_noise_metric(
            raw_orig,
            line_freq=60.0,
            bw=bw,
            guard=guard,
            picks=picks_eeg,
            nperseg=nperseg,
        )
        ln60_1 = line_noise_metric(
            raw_filt,
            line_freq=60.0,
            bw=bw,
            guard=guard,
            picks=picks_eeg,
            nperseg=nperseg,
        )

        return {
            "orig_50": ln50_0["ratio_mean"],
            "filt_50": ln50_1["ratio_mean"],
            "orig_60": ln60_0["ratio_mean"],
            "filt_60": ln60_1["ratio_mean"],
            "delta_50": ln50_1["ratio_mean"] - ln50_0["ratio_mean"],
            "delta_60": ln60_1["ratio_mean"] - ln60_0["ratio_mean"],
            "raw": {
                "ln50_before": ln50_0,
                "ln50_after": ln50_1,
                "ln60_before": ln60_0,
                "ln60_after": ln60_1,
            },
        }

    # ============================================================
    # Função "master" (3 grupos)
    # ============================================================
    def avaliar_metricas_3_grupos(raw_orig, raw_filt):
        out = {}

        out["ocular"] = ocular_metrics_frontal(raw_orig, raw_filt)
        out["muscle"] = muscle_metrics_temporal(raw_orig, raw_filt)
        out["line_noise"] = line_noise_metrics(raw_orig, raw_filt)

        return out

    def reconstruir_raw_de_epochs(epochs_corrigidos):
        from mne.io import RawArray

        dados = epochs_corrigidos.get_data()  # (n_epochs, n_channels, n_times)
        dados_reconstruidos = np.hstack(dados)  # (n_channels, total_times)

        # Identificar os canais presentes nos dados reconstruídos.
        n_canais = dados_reconstruidos.shape[0]
        ch_names_presentes = epochs_corrigidos.ch_names[:n_canais]

        # Criar a estrutura Info correspondente.
        info_novo = mne.create_info(
            ch_names=ch_names_presentes,
            sfreq=epochs_corrigidos.info["sfreq"],
            ch_types="eeg",
        )

        return RawArray(dados_reconstruidos, info_novo)

    # ---------------------------
    # Carregar o registo público PN00-1.
    # O ficheiro não faz parte do repositório; ver scripts/download_siena_pn00.py.
    # ---------------------------
    file_path = "data/PN00-1.edf"
    raw = mne.io.read_raw_edf(file_path, preload=True, verbose=True)
    # Manter apenas os canais EEG identificados pelo nome.
    eeg_chs = [ch for ch in raw.ch_names if ch.upper().startswith("EEG ")]
    raw.pick_channels(eeg_chs)
    # Normalizar os nomes antes de aplicar a montagem.
    raw = raw.rename_channels(normalize_1020_eeg_name)
    raw.set_montage(mne.channels.make_standard_montage("standard_1020"))

    # Confirmar a seleção exclusiva de canais EEG.
    picks_eeg = mne.pick_types(
        raw.info, eeg=True, meg=False, eog=False, ecg=False, stim=False, exclude="bads"
    )
    raw.pick(picks_eeg)

    # Aplicar referência média sem projeção e filtrar antes do AutoReject.
    raw_baseline = raw.set_eeg_reference("average", projection=False)
    raw_baseline.filter(
        l_freq=1.0,
        h_freq=100.0,
        method="fir",
        fir_design="firwin",
        phase="zero-double",  # Filtro de fase zero.
        verbose=False,
    )
    # Dividir o sinal em épocas com uma duração que evite uma cauda parcial.
    dur = find_epoch_duration_that_tiles_raw(
        raw_baseline, target_sec=2.0, min_sec=1.0, max_sec=3.0
    )
    print("Duração escolhida:", dur)

    epochs = mne.make_fixed_length_epochs(
        raw_baseline,
        duration=dur,
        preload=True,
        reject_by_annotation=False,
    )

    # Configurar a grelha de parâmetros do AutoReject.
    ar, meta = configure_autoreject_auto(raw_baseline, random_state=42, epoch_len=dur)
    print(meta)

    # Treinar o AutoReject uma única vez.
    ar.fit(epochs)

    # Obter o registo das épocas rejeitadas.
    reject_log = ar.get_reject_log(epochs)
    bad_idx = np.where(reject_log.bad_epochs)[0]

    good_idx = np.where(~reject_log.bad_epochs)[0]

    # Aplicar a reparação uma única vez.
    epochs_repaired = ar.transform(epochs.copy())

    # Validar a correspondência entre as épocas reparadas e as épocas aceites.
    if len(epochs_repaired) != len(good_idx):
        raise RuntimeError(
            f"AutoReject transform devolveu {len(epochs_repaired)} epochs, "
            f"mas esperava {len(good_idx)} (nº de epochs bons). "
            "Isto indica rejeições inesperadas ou uma incompatibilidade de ordem."
        )

    # Construir a saída com o mesmo número de épocas do original.
    epochs_out = epochs.copy()
    epochs_out._data[good_idx] = epochs_repaired.get_data()
    # As épocas rejeitadas permanecem com os dados originais.

    print(
        "Mantive nº epochs:",
        len(epochs_out),
        "| bad epochs (mantidos como original):",
        len(bad_idx),
    )

    raw_corrigido = reconstruir_raw_de_epochs(epochs_out)
    raw_corrigido.set_montage(raw.get_montage(), on_missing="ignore")

    left_chs, right_chs = symmetric_temporal_pairs(raw)

    results_before = compute_bsi_pre_ictal(
        raw, left_chs, right_chs, 0, 1142, 1143, 1213
    )

    results_after = compute_bsi_pre_ictal(
        raw_corrigido, left_chs, right_chs, 0, 1142, 1143, 1213
    )

    print("Antes:", results_before)
    print("Depois:", results_after)

    out = avaliar_metricas_3_grupos(raw, raw_corrigido)
    rows = metrics_to_rows(out, signal_name="PN00-1")
    export_metrics_pdf(rows, "AR_PN00-1.pdf")

finally:
    # -------------------------------------------------
    # FIM: cronómetro do script (mesmo se der erro)
    # -------------------------------------------------
    t1 = time.perf_counter()
    elapsed = t1 - t0

    h = int(elapsed // 3600)
    m = int((elapsed % 3600) // 60)
    s = elapsed % 60

    print("\n" + "=" * 60)
    print(f"Tempo total de execução: {h:02d}:{m:02d}:{s:06.3f} (hh:mm:ss.ms)")
    print("=" * 60)
