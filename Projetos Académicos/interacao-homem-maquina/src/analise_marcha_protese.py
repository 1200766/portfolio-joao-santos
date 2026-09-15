# -- coding: utf-8 --
"""
ANÁLISE DE MARCHA - DETECÇÃO AUTOMÁTICA DA PRÓTESE + CALIBRAÇÃO MANUAL 25cm + MENU TKINTER: Upload Video / Webcam / Sair
SEM ESPELHAMENTO DO VÍDEO + LINHA MÉDIA PERPENDICULAR À LINHA DA ANCA (ESTENDIDA EXATAMENTE ATÉ O PONTO MÉDIO DOS OLHOS)
+ LINHA VERDE VERTICAL ESTENDIDA AO LONGO DA IMAGEM TODA (SEMPRE PARALELA AO EIXO Y/VERTICAL, PASSANDO PELO PONTO MÉDIO DA ANCA)
+ OTIMIZADO PARA CANON EOS WEBCAM (PRIORIDADE NO BACKEND CAP_DSHOW E ÍNDICE 0)
+ REDIMENSIONAMENTO AUTOMÁTICO PARA EXIBIÇÃO EM TELAS PEQUENAS/ALTAS RESOLUÇÕES
+ OPÇÃO DE ORIENTAÇÃO (VERTICAL/HORIZONTAL) PARA WEBCAM COM ROTAÇÃO AUTOMÁTICA PARA VERTICAL
+ REGISTO DE DADOS: TEMPO VS ÂNGULO DA LINHA AMARELA (XLSX PARA EXCEL)
@author: João Amaral Santos, João Pedro Santos e Joel Pereira


@data: 20 Nov 2025
"""
import cv2
import mediapipe as mp
import numpy as np
import sys
import os
from collections import deque
import tkinter as tk
from tkinter import filedialog, messagebox
import pandas as pd # Adicionado para exportar XLSX
# ================================
# === TKINTER GUI MENU ===========
# ================================
def select_source():
    root = tk.Tk()
    root.withdraw() # Esconde janela principal
    root.title("Análise de Marcha - Seleção de Fonte")
    choice = None
    def upload_video():
        nonlocal choice
        path = filedialog.askopenfilename(
            title="Selecione o vídeo",
            filetypes=[("Arquivos de Vídeo", "*.mp4 *.avi *.mov")]
        )
        if path:
            choice = ("video", path)
            root.quit()
    def open_webcam():
        nonlocal choice
        choice = ("webcam", 1) # Índice padrão para Canon EOS (geralmente 0 ou 1)
        root.quit()
    def exit_app():
        nonlocal choice
        choice = ("exit", None)
        root.quit()
    # Janela simples
    win = tk.Toplevel(root)
    win.title("Seleção de Entrada")
    win.geometry("400x300")
    win.resizable(False, False)
    tk.Label(win, text="ANÁLISE DE MARCHA", font=("Helvetica", 16, "bold")).pack(pady=20)
    tk.Label(win, text="Escolha a fonte de vídeo:", font=("Helvetica", 12)).pack(pady=10)
    tk.Button(win, text="Carregar Vídeo", width=25, height=2, command=upload_video).pack(pady=10)
    tk.Button(win, text="Usar Webcam (Canon EOS)", width=25, height=2, command=open_webcam).pack(pady=10)
    tk.Button(win, text="Sair", width=25, height=2, command=exit_app).pack(pady=15)
    win.protocol("WM_DELETE_WINDOW", exit_app)
    win.mainloop()
    root.destroy()
    return choice
def select_orientation():
    root = tk.Tk()
    root.withdraw() # Esconde janela principal
    root.title("Análise de Marcha - Orientação da Câmera")
    orientation = None
    def horizontal():
        nonlocal orientation
        orientation = "horizontal"
        root.quit()
    def vertical():
        nonlocal orientation
        orientation = "vertical"
        root.quit()
    def exit_app():
        nonlocal orientation
        orientation = "exit"
        root.quit()
    # Janela simples
    win = tk.Toplevel(root)
    win.title("Seleção de Orientação")
    win.geometry("300x200")
    win.resizable(False, False)
    tk.Label(win, text="Escolha a orientação da câmera:", font=("Helvetica", 12)).pack(pady=20)
    tk.Button(win, text="Horizontal (1920x1080)", width=20, height=2, command=horizontal).pack(pady=10)
    tk.Button(win, text="Vertical (1080x1920)", width=20, height=2, command=vertical).pack(pady=10)
    tk.Button(win, text="Sair", width=20, height=2, command=exit_app).pack(pady=10)
    win.protocol("WM_DELETE_WINDOW", exit_app)
    win.mainloop()
    root.destroy()
    return orientation
# ================================
# === CONFIGURAÇÕES ==============
# ================================
# === Selecionar fonte via GUI ===
source_type, source_path = select_source()
if source_type == "exit":
    print("Aplicação encerrada pelo usuário.")
    sys.exit(0)
elif source_type == "video" and (not source_path or not os.path.exists(source_path)):
    messagebox.showerror("Erro", "Vídeo não encontrado!")
    sys.exit(1)
# Se webcam, selecionar orientação
orientation = None
if source_type == "webcam":
    orientation = select_orientation()
    if orientation == "exit":
        print("Aplicação encerrada pelo usuário.")
        sys.exit(0)
# Defina output_dir baseado na fonte selecionada
if source_type == "video":
    # Use o diretório do vídeo selecionado
    output_dir = os.path.join(os.path.dirname(source_path), "output")
    video_name = os.path.basename(source_path)
else:
    # webcam
    # Use o diretório atual do script para webcam
    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output")
    video_name = f"canon_eos_webcam_{orientation}.mp4" if orientation else "canon_eos_webcam.mp4" # Nome específico para Canon com orientação
# Crie a pasta de output com tratamento de erro
try:
    os.makedirs(output_dir, exist_ok=True)
    print(f"Pasta de saída: {output_dir}")
except OSError as e:
    messagebox.showerror("Erro", f"Não foi possível criar pasta de saída: {e}")
    sys.exit(1)
# === Inicializar captura (OTIMIZADO PARA CANON EOS) ===
if source_type == "video":
    cap = cv2.VideoCapture(source_path)
    print(f"Vídeo aberto: {source_path}")
    rot_code = None
    final_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    final_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
else:
    # webcam - Prioridade para Canon EOS
    # Para Canon EOS, priorize CAP_DSHOW (DirectShow) e índice 0 (comum para USB)
    cap = cv2.VideoCapture(source_path, cv2.CAP_DSHOW) # Backend otimizado para Canon no Windows
    if not cap.isOpened():
        # Fallback se CAP_DSHOW falhar
        cap = cv2.VideoCapture(source_path, cv2.CAP_MSMF)
    print(f"Canon EOS Webcam aberta no índice {source_path} com backend otimizado.")
# Verificação final de abertura
if not cap.isOpened():
    messagebox.showerror("Erro", "Falha ao abrir a Canon EOS Webcam! Feche o EOS Webcam Utility e verifique conexões.")
    sys.exit(1)
# Configurações específicas para Canon EOS (resolução e FPS recomendados)
# Sempre setar para landscape 1920x1080, rotacionar se vertical
if source_type == "webcam":
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
    if orientation == "horizontal":
        rot_code = None
        final_width = 1920
        final_height = 1080
        print("Orientação definida: Horizontal (1920x1080)")
    else: # vertical
        rot_code = cv2.ROTATE_90_COUNTERCLOCKWISE # Mude para cv2.ROTATE_90_CLOCKWISE se a rotação estiver invertida
        final_width = 1080
        final_height = 1920
        print("Orientação definida: Vertical (1080x1920) com rotação aplicada")
else:
    # Para vídeo, usa configurações originais (sem set para manter FPS e dimensões originais)
    rot_code = None
    # Não set WIDTH/HEIGHT para vídeo para preservar original
    final_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    final_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
cap.set(cv2.CAP_PROP_BUFFERSIZE, 1) # Reduz latência para live video
fps_original = cap.get(cv2.CAP_PROP_FPS)
fps = int(fps_original) if fps_original > 0 else 30
if source_type == "video":
    print(f"FPS original detectado: {fps_original}, usando: {fps}")
else:
    fps = 30  # Fixo para webcam
# Correção para evitar f-string aninhado
source_name = 'Vídeo' if source_type == 'video' else f'Canon EOS Webcam ({orientation or "horizontal"})'
print(f"Fonte: {source_name}")
print(f"Resolução final: {final_width}x{final_height}, {fps} FPS")
# Saída com dimensões finais
video_output = os.path.join(output_dir, f'analise_{"canon_eos" if source_type == "webcam" else os.path.splitext(video_name)[0]}.mp4')
out = cv2.VideoWriter(video_output, cv2.VideoWriter_fourcc(*'mp4v'), fps, (final_width, final_height))
# === MediaPipe ===
mp_pose = mp.solutions.pose
mp_drawing = mp.solutions.drawing_utils
mp_face_mesh = mp.solutions.face_mesh
pose = mp_pose.Pose(static_image_mode=False, model_complexity=1, min_detection_confidence=0.5)
face_mesh = mp_face_mesh.FaceMesh(static_image_mode=False, max_num_faces=1, refine_landmarks=True, min_detection_confidence=0.5)
# === VARIÁVEIS ===
SCALE_FACTOR = None
l_hist = deque(maxlen=30)
r_hist = deque(maxlen=30)
data = [] # Lista para registar tempo vs ângulo amarelo
# === NOVA PARTE: CONFIGURAÇÃO DA JANELA E REDIMENSIONAMENTO ===
# Torna a janela redimensionável manualmente pelo usuário
WINDOW_NAME = f"ANÁLISE DE MARCHA (SEM ESPELHAMENTO) - Canon EOS ({orientation or 'horizontal'})"
cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
# Tamanho máximo para exibição (detecção automática da tela, 80% do tamanho)
root = tk.Tk()
screen_width = root.winfo_screenwidth()
screen_height = root.winfo_screenheight()
root.destroy()
MAX_DISPLAY_WIDTH = int(screen_width * 0.8) # 80% da largura da tela
MAX_DISPLAY_HEIGHT = int(screen_height * 0.8) # 80% da altura da tela
print(f"Tamanho máximo de exibição: {MAX_DISPLAY_WIDTH}x{MAX_DISPLAY_HEIGHT}")
# === CALIBRAÇÃO MANUAL (CLIQUE EM 2 PONTOS A 25CM) ===
points = []
def mouse_callback(event, x, y, flags, param):
    global points
    if event == cv2.EVENT_LBUTTONDOWN:
        points.append((x, y))
        cv2.circle(calib_frame, (x, y), 5, (0, 255, 0), -1)
        cv2.imshow(WINDOW_NAME, calib_frame)
        if len(points) == 2:
            # Calcular distância em pixels
            dist_px = np.sqrt((points[1][0] - points[0][0])**2 + (points[1][1] - points[0][1])**2)
            global SCALE_FACTOR
            SCALE_FACTOR = 25.0 / dist_px if dist_px > 0 else None
            if SCALE_FACTOR:
                print(f"CALIBRAÇÃO MANUAL → Distância pixels: {dist_px:.1f} | Escala: {SCALE_FACTOR:.4f} cm/px")
            else:
                print("ERRO: Distância zero! Repita a calibração.")
                points = []  # Reset se erro
# Janela para calibração
cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
cv2.setMouseCallback(WINDOW_NAME, mouse_callback)
print("INICIANDO CALIBRAÇÃO MANUAL: Posicione a pessoa e clique em dois pontos a 25cm de distância (ex: ombros ou joelhos). Pressione 'c' para confirmar após cliques.")
calib_done = False
while not calib_done:
    ret, calib_frame = cap.read()
    if not ret:
        print("Fim da captura durante calibração.")
        sys.exit(1)
    # Aplicar rotação/flip para calibração também
    if rot_code is not None:
        calib_frame = cv2.rotate(calib_frame, rot_code)
    if source_type == "webcam" and orientation == "vertical":
        calib_frame = cv2.flip(calib_frame, 0)
    # Ajuste de dimensões
    if (calib_frame.shape[0] != final_height) or (calib_frame.shape[1] != final_width):
        calib_frame = cv2.resize(calib_frame, (final_width, final_height), interpolation=cv2.INTER_AREA)
    # Texto de instrução
    cv2.putText(calib_frame, "Clique em 2 pontos a 25cm (pressione 'r' para reset, 'c' para confirmar)", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
    if len(points) == 1:
        cv2.putText(calib_frame, "Ponto 1 marcado. Clique no segundo ponto.", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
    elif len(points) == 2:
        cv2.putText(calib_frame, f"Escala calculada: {SCALE_FACTOR:.4f} cm/px. Pressione 'c' para confirmar.", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
    # Desenhar linha entre pontos se 2
    if len(points) == 2:
        cv2.line(calib_frame, points[0], points[1], (0, 255, 0), 2)
    # Exibir (sem redimensionamento para calibração precisa)
    cv2.imshow(WINDOW_NAME, calib_frame)
    key = cv2.waitKey(30) & 0xFF
    if key == ord('r'):  # Reset
        points = []
    elif key == ord('c') and len(points) == 2 and SCALE_FACTOR:  # Confirmar
        calib_done = True
    elif key in [27, ord('q')]:  # Sair
        print("Calibração cancelada.")
        sys.exit(0)
cv2.destroyAllWindows()  # Fecha janela de calibração temporária
# Reabrir janela principal
cv2.namedWindow(WINDOW_NAME, cv2.WINDOW_NORMAL)
if SCALE_FACTOR is None:
    messagebox.showerror("Erro", "Calibração falhou! Escala não definida.")
    sys.exit(1)
# === LOOP PRINCIPAL ===
frame_idx = 0
print("Iniciando análise... (pressione 'q' para parar)")
# Delay dinâmico para manter tempo original (baseado no primeiro código: ajustado para FPS)
display_delay = int(1000 / fps) if source_type == "video" else 30
while True:
    ret, frame = cap.read()
    if not ret:
        print("Fim da captura.")
        break

    # Aplicar rotação se necessário (antes de processar)
    if rot_code is not None:
        frame = cv2.rotate(frame, rot_code)

    # Corrigir orientação vertical invertida (flip vertical)
    if source_type == "webcam" and orientation == "vertical":
        frame = cv2.flip(frame, 0) # Flip vertical para corrigir "de pernas para o ar"

    h, w, _ = frame.shape

    # Ajuste de dimensões pós-rotação/flip para matching com writer (garante consistência sem alterar velocidade)
    if (h != final_height) or (w != final_width):
        frame = cv2.resize(frame, (final_width, final_height), interpolation=cv2.INTER_AREA)
        h, w, _ = frame.shape

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = pose.process(rgb)
    face_results = face_mesh.process(rgb)

    # Debug para Canon EOS: Verifica se frame é preto
    if source_type == "webcam" and frame_idx % 30 == 0: # A cada 30 frames
        mean_brightness = np.mean(frame)
        print(f"Frame {frame_idx}: Brilho médio = {mean_brightness:.1f} (se <10, EOS Utility ativa)")

    # === MEDIÇÃO DAS PERNAS ===
    if results.pose_landmarks and SCALE_FACTOR:
        lm = results.pose_landmarks
        hip_l = lm.landmark[mp_pose.PoseLandmark.LEFT_HIP]
        ankle_l = lm.landmark[mp_pose.PoseLandmark.LEFT_ANKLE]
        hip_r = lm.landmark[mp_pose.PoseLandmark.RIGHT_HIP]
        ankle_r = lm.landmark[mp_pose.PoseLandmark.RIGHT_ANKLE]
        # Comprimento em cm
        l_px = np.linalg.norm([hip_l.x*w - ankle_l.x*w, hip_l.y*h - ankle_l.y*h])
        r_px = np.linalg.norm([hip_r.x*w - ankle_r.x*w, hip_r.y*h - ankle_r.y*h])
        l_cm = l_px * SCALE_FACTOR
        r_cm = r_px * SCALE_FACTOR
        l_hist.append(l_cm)
        r_hist.append(r_cm)
        l_avg = np.mean(l_hist) if l_hist else 0
        r_avg = np.mean(r_hist) if r_hist else 0

        # === DESENHO ===
        mp_drawing.draw_landmarks(frame, lm, mp_pose.POSE_CONNECTIONS)
        cv2.line(frame, (int(hip_l.x*w), int(hip_l.y*h)), (int(ankle_l.x*w), int(ankle_l.y*h)), (255,0,0), 3)
        cv2.line(frame, (int(hip_r.x*w), int(hip_r.y*h)), (int(ankle_r.x*w), int(ankle_r.y*h)), (0,0,255), 3)

        # === LINHA DA ANCA (LINHA ENTRE AS ANCAS) ===
        hip_l_px = (int(hip_l.x * w), int(hip_l.y * h))
        hip_r_px = (int(hip_r.x * w), int(hip_r.y * h))
        cv2.line(frame, hip_l_px, hip_r_px, (0, 255, 0), 2) # Linha verde entre as ancas
        # Círculo no meio da anca para visualização
        mid_x = (hip_l_px[0] + hip_r_px[0]) // 2
        mid_y = (hip_l_px[1] + hip_r_px[1]) // 2
        cv2.circle(frame, (mid_x, mid_y), 5, (0, 255, 0), -1)

        # === CÁLCULO DO PONTO MÉDIO DOS OLHOS (CORRIGIDO: CÁLCULO MANUAL) ===
        mid_eyes_px = None
        if face_results.multi_face_landmarks:
            for face_landmarks in face_results.multi_face_landmarks:
                # Landmarks dos olhos (Face Mesh)
                left_eye_left = face_landmarks.landmark[33] # LEFT_EYE_LEFT_CORNER
                left_eye_right = face_landmarks.landmark[133] # LEFT_EYE_RIGHT_CORNER
                right_eye_left = face_landmarks.landmark[362] # RIGHT_EYE_LEFT_CORNER
                right_eye_right = face_landmarks.landmark[263] # RIGHT_EYE_RIGHT_CORNER
                # Cálculo manual do centro de cada olho
                left_eye_center_x = (left_eye_left.x + left_eye_right.x) / 2
                left_eye_center_y = (left_eye_left.y + left_eye_right.y) / 2
                right_eye_center_x = (right_eye_left.x + right_eye_right.x) / 2
                right_eye_center_y = (right_eye_left.y + right_eye_right.y) / 2
                # Ponto médio entre os centros dos olhos
                mid_eyes_x = (left_eye_center_x + right_eye_center_x) / 2
                mid_eyes_y = (left_eye_center_y + right_eye_center_y) / 2
                mid_eyes_px = (int(mid_eyes_x * w), int(mid_eyes_y * h))
                # Círculo no ponto médio dos olhos para visualização (roxo)
                cv2.circle(frame, mid_eyes_px, 5, (255, 0, 255), -1)

        # === LINHA MÉDIA PERPENDICULAR À LINHA DA ANCA (ESTENDIDA EXATAMENTE ATÉ O PONTO MÉDIO DOS OLHOS) ===
        if mid_eyes_px is not None:
            eyes_y = mid_eyes_px[1]
            eyes_x = mid_eyes_px[0]
        else:
            # Fallback para nariz se face não detectada
            nose = lm.landmark[mp_pose.PoseLandmark.NOSE]
            eyes_px = (int(nose.x * w), int(nose.y * h))
            eyes_y = eyes_px[1]
            eyes_x = eyes_px[0]
            cv2.circle(frame, eyes_px, 5, (255, 0, 255), -1) # Roxo no nariz como fallback

        # Vetor da linha da anca
        dx = hip_r_px[0] - hip_l_px[0]
        dy = hip_r_px[1] - hip_l_px[1]
        # Dois possíveis vetores perpendiculares
        perp1_dx = -dy
        perp1_dy = dx
        perp2_dx = dy
        perp2_dy = -dx
        # Normalizar
        norm1 = np.sqrt(perp1_dx**2 + perp1_dy**2)
        norm2 = np.sqrt(perp2_dx**2 + perp2_dy**2)
        # Escolher direção perpendicular que aponta para cima (dy unitário < 0)
        unit_dx, unit_dy = 0, -1 # Fallback: vertical para cima
        if norm1 > 0:
            unit1_dy = perp1_dy / norm1
            if unit1_dy < 0:
                unit_dx = perp1_dx / norm1
                unit_dy = unit1_dy
        if norm2 > 0 and unit_dy >= 0: # Se o primeiro não for up, tenta o segundo
            unit2_dy = perp2_dy / norm2
            if unit2_dy < 0:
                unit_dx = perp2_dx / norm2
                unit_dy = unit2_dy
        # Calcular parâmetro t para alcançar exatamente o y dos olhos
        if abs(unit_dy) > 1e-6: # Evita divisão por zero
            t = (eyes_y - mid_y) / unit_dy
        else:
            # Se perpendicular for horizontal, usa vertical
            unit_dx = 0
            unit_dy = -1 if eyes_y < mid_y else 1
            t = abs(eyes_y - mid_y)
        # Se t < 0 (direção errada), inverte direção
        if t < 0:
            unit_dx = -unit_dx
            unit_dy = -unit_dy
            t = -t
        # Ponto final da linha (exatamente no y dos olhos, mas x ajustado pela direção; para fixar no ponto exato, projetar)
        # Para fixar exatamente no ponto médio dos olhos, calcular a projeção ou interseção
        # Aqui, usamos o t baseado em y, mas ajustamos x para coincidir com eyes_x se possível (aproximação)
        end_x = int(mid_x + unit_dx * t)
        end_y = int(mid_y + unit_dy * t) # Deve ser próximo a eyes_y
        # Ajuste fino para x coincidir com eyes_x (mantendo proporção aproximada)
        if abs(end_y - eyes_y) < 10: # Se y já está bom, ajusta x
            end_x = eyes_x
        # Garantir que fique dentro do frame
        end_x = max(0, min(w - 1, end_x))
        end_y = max(0, min(h - 1, end_y))
        # Desenhar a linha (amarela, grossura 3) da anca ao ponto médio dos olhos
        cv2.line(frame, (mid_x, mid_y), (end_x, end_y), (0, 255, 255), 3)
        # Círculo no final da linha (amarelo)
        cv2.circle(frame, (end_x, end_y), 5, (0, 255, 255), -1)

        # === CÁLCULO DOS ÂNGULOS ===
        # Ângulo da linha verde (sempre vertical: 0°)
        angle_green_deg = 0.0
        # Ângulo da linha amarela (desvio em relação à vertical)
        dx_yellow = end_x - mid_x
        dy_yellow = end_y - mid_y
        if abs(dy_yellow) > 1e-6:
            # Ângulo em graus em relação à vertical (atan2(dx, |dy|), considerando direção para cima)
            angle_yellow_deg = np.degrees(np.arctan2(abs(dx_yellow), abs(dy_yellow)))
            # Ajuste de sinal para indicar direção (positivo para direita, negativo para esquerda)
            if dx_yellow > 0:
                angle_yellow_deg = angle_yellow_deg
            else:
                angle_yellow_deg = -angle_yellow_deg
        else:
            angle_yellow_deg = 0.0

        # Registar dados: tempo vs ângulo amarelo
        time_s = frame_idx / fps
        data.append([time_s, angle_yellow_deg])

        # === LINHAS VERDES VERTICAIS ===
        # Linha vertical fixa pelo mid_x (não mexe com rotação, sempre paralela ao eixo y da imagem)
        start_pt = (mid_x, 0) # Topo da imagem
        end_pt = (mid_x, h - 1) # Fundo da imagem
        # Desenhar linha verde estendida pelo meio (grossura 2)
        cv2.line(frame, start_pt, end_pt, (0, 255, 0), 2)

        # Linha verde vertical pela anca esquerda
        left_hip_x = int(hip_l.x * w)
        left_start = (left_hip_x, 0)
        left_end = (left_hip_x, h - 1)
        cv2.line(frame, left_start, left_end, (0, 255, 0), 2)

        # Linha verde vertical pela anca direita
        right_hip_x = int(hip_r.x * w)
        right_start = (right_hip_x, 0)
        right_end = (right_hip_x, h - 1)
        cv2.line(frame, right_start, right_end, (0, 255, 0), 2)

        # === TEXTOS ===
        y = 30
        texts = [
            (f"Esquerda: {l_avg:.1f} cm", (255,0,0)),
            (f"Direita: {r_avg:.1f} cm", (0,0,255)),
            (f"Dif: {abs(l_avg-r_avg):.1f} cm", (255,255,0)),
            (f"Escala: {SCALE_FACTOR:.3f} cm/px (25cm)", (200,200,200)),
            (f"Ângulo Verde: {angle_green_deg:.1f}°", (0,255,0)),
            (f"Ângulo Amarelo: {angle_yellow_deg:.1f}°", (0,255,255))
        ]
        for txt, col in texts:
            cv2.putText(frame, txt, (10, y), cv2.FONT_HERSHEY_SIMPLEX, 0.7, col, 2)
            y += 30

    # Salvar frame (possivelmente rotacionado e flipado) no vídeo de saída
    out.write(frame)

    # === REDIMENSIONAMENTO PARA EXIBIÇÃO ===
    display_frame = frame.copy() # Copia para não alterar o original

    # Se o frame for maior que o máximo, redimensiona proporcionalmente
    if w > MAX_DISPLAY_WIDTH or h > MAX_DISPLAY_HEIGHT:
        scale_x = MAX_DISPLAY_WIDTH / w
        scale_y = MAX_DISPLAY_HEIGHT / h
        scale = min(scale_x, scale_y) # Mantém proporção (aspect ratio)
        new_w = int(w * scale)
        new_h = int(h * scale)
        display_frame = cv2.resize(display_frame, (new_w, new_h), interpolation=cv2.INTER_AREA)

    # Exibe o frame redimensionado na janela redimensionável
    cv2.imshow(WINDOW_NAME, display_frame)

    if cv2.waitKey(display_delay) & 0xFF in [27, ord('q')]:
        print("Interrompido pelo usuário.")
        break
    frame_idx += 1
# === FINALIZAÇÃO ===
cap.release()
out.release()
cv2.destroyAllWindows()
pose.close()
face_mesh.close()
# ====================== RELATÓRIO PDF PROFISSIONAL ======================
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import matplotlib.table as tbl
from datetime import datetime
if data:
    # --- Dados ---
    df = pd.DataFrame(data, columns=['Time (s)', 'Ângulo Amarelo (deg)'])
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    # Excel (mantém o teu nome)
    xlsx_output = os.path.join(output_dir, f"dados_tempo_vs_angulo_amarelo_{timestamp}.xlsx")
    df.to_excel(xlsx_output, index=False)
    # Estatísticas
    tempo_total = df['Time (s)'].iloc[-1]
    ang_medio = df['Ângulo Amarelo (deg)'].mean()
    ang_std = df['Ângulo Amarelo (deg)'].std()
    ang_max = df['Ângulo Amarelo (deg)'].abs().max()
    fora_5 = len(df[abs(df['Ângulo Amarelo (deg)']) > 5]) / len(df) * 100
    protese = ("ESQUERDA" if l_avg < r_avg - 1 else
               "DIREITA" if r_avg < l_avg - 1 else
               "Nenhuma detectada")
    pdf_path = os.path.join(output_dir, f"Relatorio_Analise_Marcha_{timestamp}.pdf")
    with PdfPages(pdf_path) as pdf:
        # === Página 1 – Capa ===
        fig1 = plt.figure(figsize=(8.27, 11.69)) # A4
        ax = fig1.add_axes([0, 0, 1, 1])
        ax.axis('off')
        ax.text(0.5, 0.88, "RELATÓRIO DE ANÁLISE DE MARCHA", ha='center', fontsize=26, fontweight='bold', color='#1f4e79')
        ax.text(0.5, 0.80, "Avaliação Biomecânica Automática", ha='center', fontsize=16, color='#2c3e50')
        ax.text(0.5, 0.65, f"Data: {datetime.now().strftime('%d/%m/%Y às %H:%M')}", ha='center', fontsize=13)
        ax.text(0.5, 0.60, f"Fonte: {source_name}", ha='center', fontsize=13)
        ax.text(0.5, 0.55, f"Prótese: {protese}", ha='center', fontsize=14,
                fontweight='bold', color='#e74c3c' if "detectada" in protese else '#27ae60')
        ax.text(0.5, 0.50, f"Duração: {tempo_total:.1f} s", ha='center', fontsize=13)
        ax.text(0.5, 0.10, "RELATÓRIO DE ANÁLISE DE MARCHA", ha='center', fontsize=10, color='#7f8c8d')
        pdf.savefig(fig1, bbox_inches='tight')
        plt.close(fig1)
        # === Página 2 – Gráfico + Tabela (CORRIGIDO) ===
        fig2 = plt.figure(figsize=(8.27, 11.69))
        gs = fig2.add_gridspec(2, 1, height_ratios=[3, 1.8], hspace=0.35) # ← hspace aqui dentro do gridspec
        # Gráfico
        ax_g = fig2.add_subplot(gs[0])
        ax_g.plot(df['Time (s)'], df['Ângulo Amarelo (deg)'], color='#007bff', linewidth=2.5)
        ax_g.fill_between(df['Time (s)'], -5, 5, color='#28a745', alpha=0.2, label='Zona normal (±5°)')
        ax_g.axhline(0, color='black', lw=1, ls='--')
        ax_g.set_title('Evolução do Ângulo de Inclinação Pélvica', fontsize=16, pad=20)
        ax_g.set_ylabel('Ângulo (°)')
        ax_g.set_xlabel('Tempo (segundos)')
        ax_g.grid(True, alpha=0.3)
        ax_g.set_ylim(-25, 25)
        # Tabela
        ax_t = fig2.add_subplot(gs[1])
        ax_t.axis('off')
        stats = [
            ["Ângulo médio", f"{ang_medio:+.2f}°"],
            ["Desvio-padrão", f"±{ang_std:.2f}°"],
            ["Máximo desvio", f"{ang_max:.2f}°"],
            ["Tempo fora ±5°", f"{fora_5:.1f}%"],
            ["Perna esquerda", f"{l_avg:.1f} cm"],
            ["Perna direita", f"{r_avg:.1f} cm"],
            ["Diferença pernas", f"{abs(l_avg-r_avg):.1f} cm"],
            ["Escala (25cm manual)", f"{SCALE_FACTOR:.4f} cm/px"],
        ]
        table = ax_t.table(cellText=stats, colLabels=["Parâmetro", "Valor"],
                           cellLoc='center', loc='center', colWidths=[0.6, 0.4])
        table.auto_set_font_size(False)
        table.set_fontsize(11)
        for (i, j), cell in table.get_celld().items():
            if i == 0:
                cell.set_facecolor('#007bff')
                cell.set_text_props(color='white', weight='bold')
            else:
                cell.set_facecolor('#f8f9fa' if i%2==0 else 'white')
        # Interpretação
        ax_t.text(0.5, -0.35,
                  "INTERPRETAÇÃO CLÍNICA\n"
                  "• -5° a +5° → Normal\n"
                  "• Desvios persistentes → possível compensação por prótese ou encurtamento\n"
                  "• Diferença pernas >1 cm → avaliação ortopédica recomendada",
                  ha='center', va='top', fontsize=11,
                  bbox=dict(facecolor='#e9ecef', edgecolor='#ced4da', boxstyle='round,pad=0.8'))
        fig2.suptitle("Relatório Completo – Análise de Marcha", fontsize=18, y=0.95)
        pdf.savefig(fig2, bbox_inches='tight')
        plt.close(fig2)
    # Mensagem final
    print("\n" + "═" * 80)
    print(" ANÁLISE CONCLUÍDA SEM ERROS!")
    print("═" * 80)
    if data:
        print(f" Vídeo anotado → {video_output}")
        print(f" Excel → {xlsx_output}")
        print(f" PDF Relatório → {pdf_path}")
        print(f" Prótese → {protese}")
    print("═" * 80)
    if os.name == 'nt' and data:
        os.startfile(output_dir)
else:
    print("Nenhum dado de ângulo registado.")
print("\nTudo pronto! Pode fechar a janela.")
