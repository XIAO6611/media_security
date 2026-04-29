% ========================================================
% 文件名: WeChat_Batch_Embed_V4.m
% 功能: 微信批量战甲生成 (新增超大分辨率手机原图自动安全缩放)
% ========================================================
clear; clc;
addpath(genpath('J-UNIWARD_matlab'));

input_dir = 'Test_Images';       
out_send_dir = 'WeChat_Send';    
out_gt_dir = 'WeChat_GT';        

payload = single(0.2);
Q_base = 85;    
Q_channel = 75; 

if ~exist(out_send_dir, 'dir'), mkdir(out_send_dir); end
if ~exist(out_gt_dir, 'dir'), mkdir(out_gt_dir); end

img_list = [dir(fullfile(input_dir, '*.tif')); dir(fullfile(input_dir, '*.pgm')); dir(fullfile(input_dir, '*.jpg'))];
num_imgs = length(img_list);

disp('======================================================');
disp(['🚀 启动 V4 级批量生成流水线，共 ', num2str(num_imgs), ' 张']);
disp('======================================================');

for k = 1:num_imgs
    img_name = img_list(k).name;
    img_raw = imread(fullfile(input_dir, img_name));
    
    % ====================================================
    % 🛡️ 【史诗级修复】：手机原图自动降维，满足助教 512 限制
    % 防止底层 C++ MEX 引擎因内存溢出而崩溃
    % ====================================================
    [img_h, img_w, ~] = size(img_raw);
    max_dim = max(img_h, img_w);
    if max_dim > 512
        scale_ratio = 512 / max_dim;
        img_raw = imresize(img_raw, scale_ratio);
        fprintf('   ⚠️ 检测到超大分辨率图 [%s]，已自动缩放至安全尺寸...\n', img_name);
    end
    
    is_color = (size(img_raw, 3) == 3);
    new_uuid = sprintf('IMG_%03d', k); 
    
    tmp_base = fullfile(out_gt_dir, 'tmp_base.jpg');
    imwrite(img_raw, tmp_base, 'Quality', Q_base); 
    jpeg_base = jpeg_read(tmp_base);
    orig_vals = double(jpeg_base.coef_arrays{1}); 
    Mo = jpeg_base.quant_tables{1};
    
    % 获取 0-255 全域亮度，和 JPEG 底层对齐
    if is_color
        img_rgb_q = imread(tmp_base);
        img_Y_pure = rgb2gray(img_rgb_q); 
    else
        img_Y_pure = imread(tmp_base);
    end
    
    tmp_sim = fullfile(out_gt_dir, 'tmp_sim.jpg');
    imwrite(img_Y_pure, tmp_sim, 'Quality', Q_channel);
    
    gt_name = fullfile(out_gt_dir, [new_uuid, '_GT.jpg']);
    stego_obj = J_UNIWARD(tmp_sim, payload); 
    jpeg_write(stego_obj, gt_name); 
    
    jpeg_I = jpeg_read(gt_name); 
    Mc = jpeg_I.quant_tables{1}; 
    S_coef = jpeg_I.coef_arrays{1};

    [rows, cols] = size(S_coef);
    step_ratio = repmat(double(Mo), rows/8, cols/8) ./ repmat(double(Mc), rows/8, cols/8);
    target_vals = double(S_coef);
    min_diff = inf(rows, cols);
    best_x_mat = zeros(rows, cols);

    for x = -2:2 
        current_diff = abs((orig_vals + x) .* step_ratio - target_vals);
        current_diff(orig_vals == 0) = inf; 
        update_mask = current_diff < min_diff;
        min_diff(update_mask) = current_diff(update_mask);
        best_x_mat(update_mask) = x;
    end
    best_x_mat(orig_vals == 0) = 0; 
    I_coef = orig_vals + best_x_mat;

    jpeg_final = jpeg_base;
    jpeg_final.coef_arrays{1} = I_coef; 
    send_name = fullfile(out_send_dir, [new_uuid, '_Send.jpg']);
    jpeg_write(jpeg_final, send_name); 
    
    delete(tmp_base); delete(tmp_sim);
    fprintf('   ✅ 生成成功: 原图[%s] -> 流水号[%s]\n', img_name, new_uuid);
end
disp('======================================================');
disp('✅ 批量完成！所有尺寸合规，请发送新的 Send 图片至微信！');