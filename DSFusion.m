% ISPMM by Garich
clear;
close all;
clc;

datasetnum = 1;  % 1=TNO， 2=LLVIP

if datasetnum == 1
    dataset = 'TNO';
    type = '.png';
    num = 42;
else
    dataset = 'LLVIP';
    type = '.jpg';
    num = 200;
end

for i=1:1
    tic
    index = i;
    infraredpath = ['C:\\Users\\admin\\Desktop\\idea\\dataset\\', dataset, '\\infrared\\', num2str(index), type];
    visiblepath = ['C:\\Users\\admin\\Desktop\\idea\\dataset\\', dataset, '\\vis\\', num2str(index), type];
    fuse_path = ['C:\\Users\\admin\\Desktop\\method\\result\\TNO\\ISPMM_1113\\', num2str(index), type];

    infraredImage = imread(infraredpath);
    visibleImage = imread(visiblepath);


    infraredImage = im2double(rgb2gray(infraredImage));
    vis = im2double(rgb2gray(visibleImage));
    
    % 设置金字塔为四层
    numslevel = 4;

    % 预先创建数据存放容器
    baseLayerInfrared = cell(numslevel, 1);
    detailLayerInfrared = cell(numslevel, 1);
    baseLayerVisible = cell(numslevel, 1);
    detailLayerVisible = cell(numslevel, 1);


    for level = 1:numslevel
        % 建立高斯滤波参数
        filterSize = 2^(numslevel - level + 2);
        h = fspecial('gaussian', [filterSize, filterSize], filterSize / 6);
        
        if level == 1
            % 高斯金字塔
            baseLayerInfrared{level} = imfilter(infraredImage, h, 'replicate', 'same');
            baseLayerVisible{level} = imfilter(vis, h, 'replicate', 'same');

            % 拉普拉斯金字塔
            detailLayerInfrared{level} = infraredImage - baseLayerInfrared{level};
            detailLayerVisible{level} = vis - baseLayerVisible{level};
        else
            % 高斯金字塔
            baseLayerInfrared{level} = imfilter(baseLayerInfrared{level - 1}, h, 'replicate', 'same');
            baseLayerVisible{level} = imfilter(baseLayerVisible{level - 1}, h, "replicate", 'same');

            % 拉普拉斯金字塔
            detailLayerInfrared{level} = baseLayerInfrared{level - 1} - baseLayerInfrared{level};
            detailLayerVisible{level} = baseLayerVisible{level - 1} - baseLayerVisible{level};
        end
        % figure, imshow(baseLayerVisible{level});
        % figure, imshow(baseLayerVisible{level});
    end
    sfilterSize = 2^(4);
    sh = fspecial('gaussian', [sfilterSize, sfilterSize], sfilterSize / 6);
    sbaseLayerInfrared = imfilter(infraredImage, sh, 'replicate', 'same');
    sbaseLayerVisible = imfilter(vis, sh, 'replicate', 'same');
    sLayerInfrared = infraredImage - sbaseLayerInfrared;
    sLayerVisible = vis - sbaseLayerVisible;
    %figure, imshow(sLayerInfrared, []);
    %figure, imshow(sLayerVisible, []);
    
    % 基础层融合
    fusedBaseLayer = max(baseLayerInfrared{1}, baseLayerVisible{1});
    % figure, imshow(fusedBaseLayer);
    
    % 细节层融合
    fusedDetailLayer = zeros(size(infraredImage));
    windowsize = [8, 8];
    step_size = [8, 8];
    for y = 1:step_size(2):(size(sLayerInfrared, 1) - windowsize(2) + 1)
        for x = 1:step_size(1):(size(sLayerInfrared, 2) - windowsize(1) + 1)
            window1 = sLayerInfrared(y:y+windowsize(2)-1, x:x+windowsize(1)-1,:);
            window2 = sLayerVisible(y:y+windowsize(2)-1, x:x+windowsize(1)-1,:);
    
            infraredImagesf = sfCalculate(window1);
            visibleImagesf = sfCalculate(window2);     
    
            infraredsfweight = infraredImagesf^(1/3);
            visiblesfweight = visibleImagesf^(1/3);
    
            ratio = infraredsfweight / (infraredsfweight + visiblesfweight);
            fusedwindow = ratio * window1 + (1 - ratio) * window2;
            fusedDetailLayer(y:y+windowsize(2)-1, x:x+windowsize(1)-1,:) = fusedwindow;
       end
    end
    
    % 显著性层融合
    fusedSaliencyLayer = zeros(size(infraredImage));
    for level = 2:4
        fusedSaliencyLayer = fusedSaliencyLayer + (detailLayerInfrared{level} + detailLayerVisible{level}) / 2;
    end
    fusedSaliencyLayer = fusedSaliencyLayer / 3;
    
    fusedimage = fusedDetailLayer * 1.2 + fusedBaseLayer * 0.9 + fusedSaliencyLayer * 0.9;

    figure, imshow(fusedimage);
    %imwrite(fusedimage, fuse_path, 'jpg');
end



% SF计算
function sf = sfCalculate(img)
    fft_image = fft2(img);
    amplitude_spectrum = abs(fft_image);
    sf = mean(amplitude_spectrum(:));
end
