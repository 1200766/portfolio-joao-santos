import os
import re

import mne
import numpy as np
from mne.preprocessing import ICA
from mne_icalabel.iclabel import iclabel_label_components
from scipy.signal import welch

ICLABEL_CLASSES = [
    "brain",
    "muscle",
    "eye",
    "heart",
    "line_noise",
    "channel_noise",
    "other",
]
ARTIFACT_CLASSES = ["muscle", "eye", "heart", "line_noise", "channel_noise"]

THRESH_TRAIN_ACC = {
    "brain": 0.44,
    "muscle": 0.18,
    "eye": 0.13,
    "heart": 0.33,
    "line_noise": 0.04,
    "channel_noise": 0.13,
    "other": 0.15,
}


def assert_channel_positions(raw):
    """
    Falha cedo se houver canais EEG sem posição 3D válida.
    Isto é crítico para o ICLabel (features topográficas).
    """
    missing = []
    for ch in raw.info["chs"]:
        if ch["kind"] != mne.io.constants.FIFF.FIFFV_EEG_CH:
            continue
        loc = ch["loc"][:3]
        if not np.isfinite(loc).all() or np.linalg.norm(loc) == 0:
            missing.append(ch["ch_name"])
    if missing:
        raise RuntimeError(
            f"Montage/posições incompletas: {len(missing)} canais EEG "
            "sem posição válida. "
            f"Exemplos: {missing[:10]}"
        )


def choose_exclude_multilabel_conservative(proba, thr=THRESH_TRAIN_ACC):
    """
    Política multi-label CONSERVADORA:
    - Define classes "ativas" por thresholds.
    - Remove IC apenas se:
        (existe pelo menos 1 artefacto ativo) AND (brain NÃO ativo)
        AND (other NÃO ativo)

    Ou seja:
    - Se brain ativo -> mantém (mesmo que eye/muscle também passem limiar).
    - Se other ativo -> mantém (porque 'other' não é sinónimo de artefacto).
    """
    exclude = []
    reasons = {}

    for k in range(proba.shape[0]):
        p = dict(zip(ICLABEL_CLASSES, proba[k]))
        active = {c for c in ICLABEL_CLASSES if p[c] >= thr[c]}
        artifacts_active = active.intersection(ARTIFACT_CLASSES)

        if (
            (len(artifacts_active) > 0)
            and ("brain" not in active)
            and ("other" not in active)
        ):
            exclude.append(k)
            reasons[k] = {
                "active": sorted(active),
                "artifacts_active": sorted(artifacts_active),
                "proba": p,
            }

    return exclude, reasons


def metrics_to_rows(metrics_out, signal_name="Sinal"):
    """
    Converte o resultado de avaliar_metricas_3_grupos() em linhas de tabela.
    """
    rows = []

    # Métricas oculares: quatro razões antes e quatro depois.
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

    # Métricas musculares: quatro valores antes e quatro depois.
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

    # Métricas de ruído de linha.
    ln = metrics_out.get("line_noise", {})
    for key, label in [("orig_50", "Line Noise 50Hz"), ("orig_60", "Line Noise 60Hz")]:
        if key in ln:
            # Emparelhar cada valor original com o valor após processamento.
            hz = "50" if "50" in key else "60"
            rows.append(
                {
                    "Grupo": "Ruído de Linha",
                    "Métrica": label,
                    "Antes": ln.get(f"orig_{hz}", np.nan),
                    "Depois": ln.get(f"filt_{hz}", np.nan),
                }
            )

    # Calcular a diferença entre os valores posteriores e anteriores.
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
    out_dir="outputs/metrics/ica-iclabel",
    title="Relatório de Métricas (Antes vs Depois)",
):
    """
    Guarda o PDF em out_dir/filename. Cria a pasta se não existir.
    """
    os.makedirs(out_dir, exist_ok=True)
    out_pdf_path = os.path.join(out_dir, filename)

    # Dependências usadas exclusivamente na exportação do relatório.
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

    # ordenar por lateralidade (|x| maior)
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

    picks = mne.pick_types(raw.info, eeg=True, meg=False, eog=False, exclude=exclude)
    eeg_names = [raw.ch_names[i] for i in picks]

    temporal_left = []
    temporal_right = []

    for ch in eeg_names:
        if ch not in ch_pos:
            continue
        x, y, _ = ch_pos[ch]

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

    # remover prefixo típico
    if name.upper().startswith("EEG "):
        name = name[4:].strip()

    # Normalizações específicas, sensíveis a maiúsculas e minúsculas.
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
        # 2 s por defeito (robusto e suficiente em muitos casos)
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
def ocular_metrics_frontal(raw_orig, raw_filt, y_thr=0.07, bandas=None, nperseg=None):
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
            k: [] for k in ["Delta/Beta", "Delta/Alpha", "Theta/Beta", "Theta/Alpha"]
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

            # bandpowers
            P_alpha = bandpower_from_psd(freqs, psd, *bandas["Alpha"])
            P_beta = bandpower_from_psd(freqs, psd, *bandas["Beta"])
            P_gamma = bandpower_from_psd(freqs, psd, *bandas["Gamma"])

            # ratios
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

            # high-frequency power > 35 Hz
            hf = bandpower_from_psd(freqs, psd, hf_min, freqs[-1])
            hf_list.append(hf)

            # 1/f slope (log-log fit)
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
def line_noise_metric(raw, line_freq=50.0, bw=1.0, guard=2.0, picks=None, nperseg=None):
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
        raw_orig, line_freq=50.0, bw=bw, guard=guard, picks=picks_eeg, nperseg=nperseg
    )
    ln50_1 = line_noise_metric(
        raw_filt, line_freq=50.0, bw=bw, guard=guard, picks=picks_eeg, nperseg=nperseg
    )

    ln60_0 = line_noise_metric(
        raw_orig, line_freq=60.0, bw=bw, guard=guard, picks=picks_eeg, nperseg=nperseg
    )
    ln60_1 = line_noise_metric(
        raw_filt, line_freq=60.0, bw=bw, guard=guard, picks=picks_eeg, nperseg=nperseg
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
# Agregação dos três grupos de métricas
# ============================================================
def avaliar_metricas_3_grupos(raw_orig, raw_filt):
    out = {}

    out["ocular"] = ocular_metrics_frontal(raw_orig, raw_filt)
    out["muscle"] = muscle_metrics_temporal(raw_orig, raw_filt)
    out["line_noise"] = line_noise_metrics(raw_orig, raw_filt)

    return out


# ---------------------------
# Carregar o registo público PN00-4.
# ---------------------------
# O ficheiro não faz parte do repositório; ver scripts/download_siena_pn00.py.
file_path = "data/PN00-4.edf"
raw = mne.io.read_raw_edf(file_path, preload=True, verbose=True)
# Manter apenas os canais identificados como EEG no ficheiro de origem.
eeg_chs = [ch for ch in raw.ch_names if ch.upper().startswith("EEG ")]
raw.pick_channels(eeg_chs)
# Normalizar os nomes antes de associar a montagem standard 10-20.
raw = raw.rename_channels(normalize_1020_eeg_name)
raw.set_montage(mne.channels.make_standard_montage("standard_1020"))

# Selecionar os canais EEG válidos para o processamento.
picks_eeg = mne.pick_types(
    raw.info, eeg=True, meg=False, eog=False, ecg=False, stim=False, exclude="bads"
)
raw.pick(picks_eeg)

# Referência e filtro para ICA
raw_baseline = raw.set_eeg_reference("average", projection=False)
raw_baseline.filter(
    l_freq=1.0,
    h_freq=100.0,
    method="fir",
    fir_design="firwin",
    phase="zero-double",  # Filtro com fase zero.
    verbose=False,
)

# Verificar a montagem e as posições dos canais.
assert_channel_positions(raw_baseline)

ica = ICA(
    n_components=0.99,  # Preservar 99% da variância.
    max_iter="auto",
    method="infomax",
    random_state=97,
    fit_params=dict(extended=True),
)

ica.fit(raw_baseline.copy())

proba = iclabel_label_components(raw_baseline, ica, inplace=True)
exclude_idx, reasons = choose_exclude_multilabel_conservative(
    proba, thr=THRESH_TRAIN_ACC
)

print(
    f"ICs a excluir (multi-label conservador): {len(exclude_idx)} / {ica.n_components_}"
)
for k in exclude_idx[:30]:
    best = ICLABEL_CLASSES[int(np.argmax(proba[k]))]
    conf = float(np.max(proba[k]))
    print(f"  IC {k}: best={best} conf={conf:.2f} active={reasons[k]['active']}")
raw_corrigido_final = ica.apply(raw_baseline.copy(), exclude=exclude_idx)

out = avaliar_metricas_3_grupos(raw_baseline, raw_corrigido_final)
rows = metrics_to_rows(out, signal_name="PN00-4")
export_metrics_pdf(rows, "ICA+ICLabel_PN00-4.pdf")

raw_baseline.plot(title="Sinal PN00-4 padronizado")
raw_corrigido_final.plot(title="Sinal PN00-4 com ICA+ICLabel")
input("Pressione Enter para continuar...")

os.makedirs("outputs/signals/ica-iclabel", exist_ok=True)
raw_corrigido_final.save(
    "outputs/signals/ica-iclabel/PN00-4_corrigido.fif", overwrite=True
)
