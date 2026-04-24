% ========================================================
% 文件名: Reproduce_Final_MegaBatch.m
% 终极任务: 双数据集 + 6组载荷梯度 全自动扫描脚本
% 特性: 自动处理不同格式、自动备份数据、自动生成 Markdown 表格
% ========================================================
clear; clc;
addpath(genpath('J-UNIWARD_matlab')); % 载入依赖库

% --- 1. 终极实验配置 ---
% 定义要测试的载荷梯度
payloads = single([0.05, 0.1, 0.2, 0.3, 0.4, 0.5]); 
Qc = 95;            % 信道攻击强度
num_to_test = 5;  % 每个数据集抽取前 100 张测试

% 定义数据集结构体 (把 UCID 和 BOSSbase 打包)
datasets(1).name = 'UCID';
datasets(1).folder = 'UCID1338';    % 确保你的文件夹名字是这个
datasets(1).ext = '*.tif';

datasets(2).name = 'BOSSbase';
datasets(2).folder = 'BOSSbase_1.01'; % 确保你的文件夹名字是这个
datasets(2).ext = '*.pgm';

% --- 2. 环境初始化 ---
temp_dir = 'imageT';
if ~exist(temp_dir, 'dir')
    mkdir(temp_dir);
end

% 初始化结果存储矩阵：行对应载荷，列对应数据集
% 存储标准版的 BER
results_std = zeros(length(payloads), length(datasets)); 
% 存储鲁棒版(-P)的 BER
results_rob = zeros(length(payloads), length(datasets));

disp('======================================================');
disp('🚀 启动终极自动化扫描... 这将是一场漫长但伟大的计算！');
disp(['📊 测试规模: ', num2str(length(datasets)), ' 个数据集 × ', ...
      num2str(length(payloads)), ' 个载荷 × ', num2str(num_to_test), ' 张图']);
disp('======================================================');

total_tic = tic;

% --- 3. 核心大循环 ---
for d = 1:length(datasets)
    curr_data = datasets(d);
    img_list = dir(fullfile(curr_data.folder, curr_data.ext));
    
    if length(img_list) < num_to_test
        error(['图库 ', curr_data.name, ' 中的图片数量不足 ', num2str(num_to_test), ' 张！']);
    end
    
    disp(['>>> 开始攻克数据集: [ ', curr_data.name, ' ] ...']);
    
    for p = 1:length(payloads)
        curr_payload = payloads(p);
        disp(['    > 正在测试 Payload = ', num2str(curr_payload), ' ...']);
        
        % 当前载荷下的累加器
        tot_err_std = 0; tot_bits_std = 0;
        tot_err_rob = 0; tot_bits_rob = 0;
        
        % 遍历该数据集的前 100 张图
        for k = 1:num_to_test
            img_name = img_list(k).name;
            cover_raw_path = fullfile(curr_data.folder, img_name);
            
            % 临时文件路径
            cover_jpg_path = fullfile(temp_dir, 'tmp_cover.jpg');
            std_stego_path = fullfile(temp_dir, 'tmp_stego_std.jpg');
            std_att_path   = fullfile(temp_dir, 'tmp_att_std.jpg');
            chan_comp_path = fullfile(temp_dir, 'tmp_chan_comp.jpg');
            int_stego_path = fullfile(temp_dir, 'tmp_stego_int.jpg');
            
            % --- 格式兼容处理 (彩色转灰度，直接读灰度) ---
            img_O = imread(cover_raw_path);
            if size(img_O, 3) == 3
                img_O = rgb2gray(img_O);
            end
            imwrite(img_O, cover_jpg_path, 'Quality', 100);

            %% --- 管线 A: 标准版 ---
            stego_obj_std = J_UNIWARD(cover_jpg_path, curr_payload);
            jpeg_write(stego_obj_std, std_stego_path);
            
            imwrite(imread(std_stego_path), std_att_path, 'Quality', Qc);
            
            jpeg_S_std = jpeg_read(std_stego_path);
            jpeg_A_std = jpeg_read(std_att_path);
            
            nz_idx_std = (jpeg_S_std.coef_arrays{1} ~= 0);
            bit_S_std = mod(abs(jpeg_S_std.coef_arrays{1}(nz_idx_std)), 2);
            bit_A_std = mod(abs(jpeg_A_std.coef_arrays{1}(nz_idx_std)), 2);
            
            tot_err_std = tot_err_std + sum(bit_S_std ~= bit_A_std);
            tot_bits_std = tot_bits_std + sum(nz_idx_std(:));

            %% --- 管线 B: 鲁棒 P 版 ---
            imwrite(img_O, chan_comp_path, 'Quality', Qc);
            stego_obj_int = J_UNIWARD(chan_comp_path, curr_payload);
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

            % 数学信道攻击
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
            
            tot_err_rob = tot_err_rob + sum(bit_S_rob ~= bit_A_rob);
            tot_bits_rob = tot_bits_rob + sum(nz_idx_rob(:));
            
            % 清理当前图片临时文件
            delete(cover_jpg_path); delete(std_stego_path); delete(std_att_path);
            delete(chan_comp_path); delete(int_stego_path); 
        end % 图片循环结束
        
        % 记录这一组 (图库+载荷) 的平均 BER
        results_std(p, d) = tot_err_std / tot_bits_std * 100;
        results_rob(p, d) = tot_err_rob / tot_bits_rob * 100;
        
        fprintf('      [完成] 标准BER: %.2f%%, 鲁棒BER: %.2f%%\n', results_std(p, d), results_rob(p, d));
        
        % 【安全防线】：每跑完一组载荷，立刻存盘，防止电脑死机！
        save('Final_MegaBatch_Backup.mat', 'payloads', 'datasets', 'results_std', 'results_rob');
        
    end % 载荷循环结束
    disp('------------------------------------------------------');
end % 图库循环结束

total_time = toc(total_tic);

% --- 4. 自动生成可以直接贴进报告的 Markdown 表格 ---
disp(' ');
disp('================================================================');
disp('🎉 终极计算全部完成！耗时: '); disp(duration(0,0,total_time));
disp('================================================================');
disp('【请直接复制以下表格到你的实验报告中】');
disp(' ');
fprintf('| 载荷 (Payload) | UCID 标准版 | UCID 鲁棒版(P) | BOSSbase 标准版 | BOSSbase 鲁棒版(P) |\n');
fprintf('| :---: | :---: | :---: | :---: | :---: |\n');

for p = 1:length(payloads)
    fprintf('| %.2f | %.2f %% | **%.2f %%** | %.2f %% | **%.2f %%** |\n', ...
            payloads(p), ...
            results_std(p, 1), results_rob(p, 1), ... % UCID 的数据
            results_std(p, 2), results_rob(p, 2));    % BOSSbase 的数据
end
disp('================================================================');