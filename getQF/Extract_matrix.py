from PIL import Image

# 填入你那张测出总和为 151 的图片路径
img_path = "./main/wechat_test_yd/ps1/微信图片_20260422171225.jpg"  

img = Image.open(img_path)
q_tables = getattr(img, 'quantization', None)

if q_tables and 0 in q_tables:
    luma_table = q_tables[0]
    print("窃取到的微信专属 8x8 量化矩阵：")
    print("Mc_wechat = [")
    for i in range(8):
        row = luma_table[i*8 : (i+1)*8]
        print("    " + ", ".join(map(str, row)) + ";")
    print("];")