import os
from PIL import Image

def batch_jpg_to_pgm(input_dir, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    # 遍历所有 jpg/jpeg
    for fname in os.listdir(input_dir):
        if fname.lower().endswith((".jpg", ".jpeg")):
            in_path = os.path.join(input_dir, fname)
            # 后缀替换为 .pgm
            name_no_ext = os.path.splitext(fname)[0]
            out_path = os.path.join(output_dir, f"{name_no_ext}.pgm")

            # 转灰度图 L = 单通道灰度
            img = Image.open(in_path).convert("L")
            # 保存为标准 PGM
            img.save(out_path)
            print(f"转换完成：{fname} → {name_no_ext}.pgm")

if __name__ == "__main__":
    # ============ 只改这两行路径 ============
    # 你的 jpg 文件夹
    JPG_FOLDER = r"C:\Users\dl\Desktop\dataset\test\stego"
    # 输出 pgm 存放文件夹（可同目录）
    PGM_OUTPUT_FOLDER = r"C:\Users\dl\Desktop\dataset\test\stego_pgm"
    # ========================================

    batch_jpg_to_pgm(JPG_FOLDER, PGM_OUTPUT_FOLDER)
    print("\n✅ 全部 JPG 已转为标准灰度 PGM，可直接用于 XuNet 测试")