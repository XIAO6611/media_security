% ========================================================
% 文件名: WeChat_Batch_Extract_V3.m
% 功能: 微信实战批量提取 (严格比对 GT 标准答案)
% ========================================================
clear; clc;
addpath(genpath('J-UNIWARD_matlab'));

recv_dir = 'WeChat_Received';    
gt_dir = 'WeChat_Send';            

recv_list = dir(fullfile(recv_dir, '*_Recv.jpg'));
num_imgs = length(recv_list);

if num_imgs == 0
    error('未找到图片！请确保微信保存后按 IMG_xxx_Recv.jpg 重命名。');
end

disp('======================================================');
disp(['📊 启动严格匹配验证流水线，共计 ', num2str(num_imgs), ' 张']);
disp('======================================================');

total_err = 0;
total_bits = 0;
ber_array = [];

for k = 1:num_imgs
    recv_name = recv_list(k).name;
    base_uuid = strrep(recv_name, '_Recv.jpg', ''); 
    gt_name = [base_uuid, '_Send.jpg'];
    
    recv_path = fullfile(recv_dir, recv_name);
    gt_path = fullfile(gt_dir, gt_name);
    
    if ~exist(gt_path, 'file')
        warning('❌ 找不到对应的标准答案 [%s]，跳过！', gt_name);
        continue;
    end
    
    jpeg_R = jpeg_read(recv_path);
    R_coef = jpeg_R.coef_arrays{1};
    jpeg_S = jpeg_read(gt_path);
    S_coef = jpeg_S.coef_arrays{1};
    
    if any(size(R_coef) ~= size(S_coef))
        warning('❌ 尺寸严重不符 [%s]，跳过！', base_uuid);
        continue;
    end
    
    nz_idx = (S_coef ~= 0);
    [rows, cols] = size(S_coef);
    for i = 1:8:rows
        for j = 1:8:cols
            nz_idx(i, j) = false; % 强制排除 DC 系数
        end
    end
    
    bit_R = bitand(int32(abs(R_coef(nz_idx))), 1);
    bit_S = bitand(int32(abs(S_coef(nz_idx))), 1);
    
    err_count = sum(bit_R ~= bit_S);
    bits_count = sum(nz_idx(:));
    
    curr_ber = (err_count / bits_count) * 100;
    ber_array(end+1) = curr_ber;
    
    total_err = total_err + err_count;
    total_bits = total_bits + bits_count;
    
    fprintf('   验证: %s | 错码: %4d / %5d | BER: %5.2f%%\n', base_uuid, err_count, bits_count, curr_ber);
end

global_avg_ber = (total_err / total_bits) * 100;

disp('======================================================');
disp('🏆 V3 批量实战测试最终报告');
fprintf('综合全局 BER : %.4f %%\n', global_avg_ber);
fprintf('单图最高 BER : %.4f %%\n', max(ber_array));
fprintf('单图最低 BER : %.4f %%\n', min(ber_array));
disp('======================================================');