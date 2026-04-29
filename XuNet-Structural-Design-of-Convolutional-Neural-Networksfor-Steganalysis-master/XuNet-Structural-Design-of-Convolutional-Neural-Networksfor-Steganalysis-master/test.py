"""This module is used to test the XuNet model."""
from glob import glob
import torch
import numpy as np
import imageio.v2 as io
from PIL import Image
from model.model import XuNet

TEST_BATCH_SIZE = 40

COVER_PATH = "C:\\Users\\dl\\Desktop\\dataset\\test\\cover\\*.pgm"
STEGO_PATH = "C:\\Users\\dl\\Desktop\\dataset\\test\\stego_pgm\\*.pgm"
CHKPT = "./checkpoints/net_44.pt"

cover_image_names = glob(COVER_PATH)
stego_image_names = glob(STEGO_PATH)

model = XuNet().cpu()
ckpt = torch.load(CHKPT, map_location="cpu")
model.load_state_dict(ckpt["model_state_dict"])

# 固定输入 512x512
images = torch.empty((TEST_BATCH_SIZE, 1, 512, 512), dtype=torch.float)
test_accuracy = []

# ✅ 自动缩放到 512×512，解决所有尺寸报错！
def resize_to_512(img):
    img = Image.fromarray(img)
    img = img.resize((512, 512), Image.Resampling.LANCZOS)
    return np.array(img)

for idx in range(0, len(cover_image_names), TEST_BATCH_SIZE // 2):
    cover_batch = cover_image_names[idx : idx + TEST_BATCH_SIZE // 2]
    stego_batch = stego_image_names[idx : idx + TEST_BATCH_SIZE // 2]

    batch = []
    batch_labels = []
    xi = 0
    yi = 0

    for i in range(2 * len(cover_batch)):
        if i % 2 == 0:
            batch.append(stego_batch[xi])
            batch_labels.append(1)
            xi += 1
        else:
            batch.append(cover_batch[yi])
            batch_labels.append(0)
            yi += 1

    for i in range(len(batch)):
        img = io.imread(batch[i])
        img = resize_to_512(img)  # ✅ 这里自动修复尺寸
        images[i, 0, :, :] = torch.tensor(img).cpu()

    image_tensor = images[:len(batch)].cpu()
    batch_labels = torch.tensor(batch_labels, dtype=torch.long).cpu()

    outputs = model(image_tensor)
    prediction = outputs.data.max(1)[1]

    accuracy = prediction.eq(batch_labels.data).sum() * 100.0 / batch_labels.size(0)
    test_accuracy.append(accuracy.item())

# ✅ 修复这里！！！
final_acc = sum(test_accuracy) / len(test_accuracy)
print("test_accuracy = {:.2f}".format(final_acc))
# print(f"test_accuracy = {sum(test_accuracy)/len(test_accuracy):%.2f}")