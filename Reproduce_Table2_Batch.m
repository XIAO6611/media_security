% ========================================================
% 文件名: Reproduce_Table1_Batch.m (终极测试版)
% 特性: 
% 1. LSB 奇偶校验 + 纯数学域预补偿模拟
% 2. 自动创建 imageT 临时文件夹，保持根目录纯净
% 3. 修复了未生成文件的 delete 警告
% ========================================================
clear; clc;
addpath(genpath('J-UNIWARD_matlab')); % 确保能找到所有依赖库

% --- 1. 实验参数配置 ---
img_folder = 'UCID1338';          % 你的图库文件夹名字
payload = single(0.2);            % 嵌入率
Qc = 95;                          % 信道攻击强度

% --- 2. 临时文件夹配置 (核心修改点) ---
temp_dir = 'imageT';
if ~exist(temp_dir, 'dir')
    mkdir(temp_dir);              % 如果没有 imageT 文件夹，自动创建一个
end

% 获取文件夹下所有的 .tif 文件
img_list = dir(fullfile(img_folder, '*.tif'));
total_images = length(img_list);

if total_images == 0
    error('未在指定文件夹找到图片，请检查 img_folder 路径！');
end

% 测试数量 (可以改成 total_images 跑全库)
num_to_test = min(50, total_images); 

disp(['>>> 开始批量测试，共计 ', num2str(num_to_test), ' 张图片...']);
disp(['>>> 参数: Payload = ', num2str(payload), ', Qc = ', num2str(Qc)]);
disp(['>>> 临时文件将安全存放在: ./', temp_dir, '/ 目录下']);
disp('======================================================');

% 初始化全局累加器
total_err_std = 0;  total_bits_std = 0;
total_err_rob = 0;  total_bits_rob = 0;

tic; % 开启计时

for k = 1:num_to_test
    img_name = img_list(k).name;
    cover_tif_path = fullfile(img_folder, img_name);
    
    % 【核心优化：将临时文件路径全部指向 imageT 文件夹】
    cover_jpg_path = fullfile(temp_dir, sprintf('tmp_cover_%d.jpg', k));
    std_stego_path = fullfile(temp_dir, sprintf('tmp_stego_std_%d.jpg', k));
    std_att_path   = fullfile(temp_dir, sprintf('tmp_att_std_%d.jpg', k));
    chan_comp_path = fullfile(temp_dir, sprintf('tmp_chan_comp_%d.jpg', k));
    int_stego_path = fullfile(temp_dir, sprintf('tmp_stego_int_%d.jpg', k));
    
    % 注意：鲁棒图 (rob_stego_path) 被我们删掉了，因为纯数学域计算不需要存盘！
    
    fprintf('正在处理 [%d/%d]: %s ... ', k, num_to_test, img_name);
    
    % --- 0. 格式转换 ---
    img_O = imread(cover_tif_path);
    if size(img_O, 3) == 3
        img_O = rgb2gray(img_O);
    end
    imwrite(img_O, cover_jpg_path, 'Quality', 100);

    %% --- 测试 1：标准 J-UNIWARD ---
    stego_obj_std = J_UNIWARD(cover_jpg_path, payload);
    jpeg_write(stego_obj_std, std_stego_path);
    
    img_standard = imread(std_stego_path);
    imwrite(img_standard, std_att_path, 'Quality', Qc);
    
    jpeg_S_std = jpeg_read(std_stego_path);
    jpeg_A_std = jpeg_read(std_att_path);
    
    nz_idx_std = (jpeg_S_std.coef_arrays{1} ~= 0);
    bit_S_std = mod(abs(jpeg_S_std.coef_arrays{1}(nz_idx_std)), 2);
    bit_A_std = mod(abs(jpeg_A_std.coef_arrays{1}(nz_idx_std)), 2);
    
    err_std_current = sum(bit_S_std ~= bit_A_std);
    bits_std_current = sum(nz_idx_std(:));
    
    total_err_std = total_err_std + err_std_current;
    total_bits_std = total_bits_std + bits_std_current;

    %% --- 测试 2：J-UNIWARD-P ---
    imwrite(img_O, chan_comp_path, 'Quality', Qc);
    stego_obj_int = J_UNIWARD(chan_comp_path, payload);
    jpeg_write(stego_obj_int, int_stego_path);
    
    jpeg_O = jpeg_read(cover_jpg_path);   Mo = jpeg_O.quant_tables{1}; 
    jpeg_Int = jpeg_read(int_stego_path); Mc = jpeg_Int.quant_tables{1}; 
    S_coef = jpeg_Int.coef_arrays{1};

    I_coef = zeros(size(S_coef));
    [rows, cols] = size(S_coef);
    for i = 1:rows
        for j = 1:cols
            u = mod(i-1, 8) + 1; v = mod(j-1, 8) + 1;
            step_o = Mo(u, v); step_c = Mc(u, v);
            
            orig_val = jpeg_O.coef_arrays{1}(i, j);
            target_val = S_coef(i, j);
            
            min_diff = inf; best_x = 0;
            for x = -3:3 
                diff = abs((orig_val + x) * (step_o / step_c) - target_val);
                if diff < min_diff
                    min_diff = diff; best_x = x;
                end
            end
            I_coef(i, j) = orig_val + best_x;
        end
    end

    % 模拟纯数学 DCT 域信道攻击
    attacked_coef = zeros(size(I_coef));
    for i = 1:rows
        for j = 1:cols
            u = mod(i-1, 8) + 1; v = mod(j-1, 8) + 1;
            attacked_coef(i,j) = round( I_coef(i,j) * (Mo(u,v) / Mc(u,v)) );
        end
    end
    
    nz_idx_rob = (S_coef ~= 0);
    bit_S_rob = mod(abs(S_coef(nz_idx_rob)), 2);
    bit_A_rob = mod(abs(attacked_coef(nz_idx_rob)), 2);
    
    err_rob_current = sum(bit_S_rob ~= bit_A_rob);
    bits_rob_current = sum(nz_idx_rob(:));
    
    total_err_rob = total_err_rob + err_rob_current;
    total_bits_rob = total_bits_rob + bits_rob_current;
    
    fprintf('完成! 标准BER: %.1f%%, 鲁棒BER: %.1f%%\n', ...
        (err_std_current/bits_std_current)*100, (err_rob_current/bits_rob_current)*100);
    
    % 【完美打扫战场】：只删除在 imageT 真实生成的 5 个临时文件，绝不报错！
    delete(cover_jpg_path); delete(std_stego_path); delete(std_att_path);
    delete(chan_comp_path); delete(int_stego_path); 
end

% --- 输出全局平均统计 ---
avg_BER_std = total_err_std / total_bits_std;
avg_BER_rob = total_err_rob / total_bits_rob;
elapsed_time = toc;

disp('======================================================');
disp(['🎉 测试完成！共计 ', num2str(num_to_test), ' 张图片的全局平均结果：']);
fprintf('⏱️ 耗时: %.1f 秒\n', elapsed_time);
fprintf('❌ 标准 J-UNIWARD 全局平均误码率 (BER): %.2f %%\n', avg_BER_std * 100);
fprintf('✅ 鲁棒 J-UNIWARD-P 全局平均误码率 (BER): %.2f %%\n', avg_BER_rob * 100);
disp('======================================================');