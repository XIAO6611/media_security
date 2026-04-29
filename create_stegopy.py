import os
import cv2
import numpy as np
from tqdm import tqdm

# ====================== 【你只需改这4个路径】 ======================
TRAIN_COVER_DIR = r"C:\Users\dl\Desktop\dataset\train\cover"
TRAIN_STEGO_DIR = r"C:\Users\dl\Desktop\dataset\train\stego"

VALID_COVER_DIR = r"C:\Users\dl\Desktop\dataset\valid\cover"
VALID_STEGO_DIR = r"C:\Users\dl\Desktop\dataset\valid\stego"

EMBEDDING_RATE = 0.4  # 隐写强度
# ====================================================================

os.makedirs(TRAIN_STEGO_DIR, exist_ok=True)
os.makedirs(VALID_STEGO_DIR, exist_ok=True)

def safe_embed(cover, rate=0.4):
    """
    安全、不爆内存、不报错的隐写算法
    专门为 BOSSBase 512x512.pgm 设计
    隐写分析训练完全可用
    """
    img = cover.copy().astype(np.int16)
    h, w = img.shape

    num_bits = int(h * w * rate)
    coords = np.random.choice(h*w, num_bits, replace=False)

    for idx in coords:
        i = idx // w
        j = idx % w
        img[i,j] ^= 1  # LSB 翻转（标准隐写）

    return np.clip(img, 0, 255).astype(np.uint8)

def process_folder(cover_dir, stego_dir):
    files = sorted([f for f in os.listdir(cover_dir) if f.endswith(".pgm")])
    print(f"处理：{cover_dir}")

    for f in tqdm(files):
        path = os.path.join(cover_dir, f)
        out_path = os.path.join(stego_dir, f)

        img = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
        if img is None or img.shape != (512,512):
            continue

        stego = safe_embed(img, EMBEDDING_RATE)
        cv2.imwrite(out_path, stego)

if __name__ == "__main__":
    print("===== 安全版隐写生成器 无内存错误 =====")
    process_folder(TRAIN_COVER_DIR, TRAIN_STEGO_DIR)
    process_folder(VALID_COVER_DIR, VALID_STEGO_DIR)
    print("✅ 全部完成！")