import os
import csv
from PIL import Image
import hashlib

def analyze_mobile_wechat_qf(root_folder, output_csv="mobile_wechat_qf_results.csv"):
    print(f"开始扫描移动端测试文件夹: {root_folder}")
    print("-" * 60)
    
    results = []
    
    # 自动遍历所有子文件夹（完美适配区分“私聊”和“朋友圈”场景）
    for dirpath, dirnames, filenames in os.walk(root_folder):
        # 获取当前场景名称（文件夹名）
        scenario_name = os.path.basename(dirpath)
        
        for filename in filenames:
            if filename.lower().endswith(('.jpg', '.jpeg')):
                file_path = os.path.join(dirpath, filename)
                try:
                    img = Image.open(file_path)
                    
                    # 确保是JPEG并且包含量化表
                    if img.format == 'JPEG':
                        q_tables = getattr(img, 'quantization', None)
                        if q_tables and 0 in q_tables:
                            luma_table = q_tables[0] # 获取亮度量化表
                            
                            table_sum = sum(luma_table)
                            table_hash = hashlib.md5(str(luma_table).encode('utf-8')).hexdigest()[:8] 
                            resolution = f"{img.width}x{img.height}"
                            
                            # 将结果记录下来
                            results.append([scenario_name, filename, resolution, table_sum, table_hash])
                            print(f"成功提取: [{scenario_name}] {filename} -> 量化表之和: {table_sum}")
                        else:
                            print(f"跳过: [{scenario_name}] {filename} (未找到量化表)")
                except Exception as e:
                    print(f"❌ 报错: [{scenario_name}] {filename} ({str(e)})")
                    
    # 将结果写入 CSV 表格
    with open(output_csv, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.writer(f)
        writer.writerow(['发送场景 (文件夹)', '文件名', '接收后分辨率', '亮度量化表之和', '量化表指纹(Hash)'])
        writer.writerows(results)
        
    print("-" * 60)
    print(f"分析完成！一共成功提取了 {len(results)} 张移动端图片的量化表。")
    print(f"结果已保存至: {output_csv}")

# ==========================================
# 你的移动端测试总文件夹路径
# 建议在里面建两个子文件夹：Private_Chat 和 Moments
# ==========================================
ROOT_DIR = "./main/wechat_test_yd" 
analyze_mobile_wechat_qf(ROOT_DIR, output_csv="./main/mobile_wechat_qf_results.csv")
# 运行分析
# analyze_mobile_wechat_qf(ROOT_DIR)