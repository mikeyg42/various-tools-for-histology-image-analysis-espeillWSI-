function [D, tform, M_Im, movedMask] = registerSerialSections_part2_nonrigid(varargin)
%syntax: [D, tform, M_Im, movedMask] = registerSerialSections_part2_nonrigid(varargin)

%% Part 2 of registration: nonrigid geometric transformation with control points placed EXCLUSIVELY programically .
% name of the game is placing control points programmically, and with great care.

%Using these points, I try 3 different nonrigid registration (LWH /2deg+3deg polynomial) techniques. 
% After user picks the best of those, I follow up with a quick call of Thirion's demons
% algorithm, after which, images are usually very much aligned smoothly. registration is
% applied simultaneously to the image and its mask. 

%Michael Glendinning, 2023
% note - some aspects of this script are still a work in progress! They are actively being
% worked on however.


id = 'MATLAB:polyshape:repairedBySimplify';
warning('off', id);

%% load up variables saved 
if nargin ~= 3
    ld = load('/your/dir//registration_data_ID_stain1_stain2.mat',...
        '-mat');
    myNEWimages = ld.images_part1;
    fixedMat = ld.fixedMat;
    movingMat = ld.movingMat;
else
    myNEWimages = varargin{3};
    fixedMat = varargin{1};
    movingMat = varargin{2};
end

MOVING_gray = myNEWimages{2};
MOVING_mask = myNEWimages{1};
IMG_gray = myNEWimages{4};
IMG_mask = myNEWimages{3};

MOVING_gray(~MOVING_mask) = 1;
IMG_gray(~IMG_mask) = 1;

%% define evenly spaced points along each of the four edges -- will become the majority of control points

%----------------------------------------------------------------------------
% start first with the fixed image
%----------------------------------------------------------------------------
% 1. make hull
[ay, ax]=find(IMG_mask); 
hull_1 = convhull(ax, ay);

% 2. convert hull into polyshape
HULL_image1 = polybuffer(polyshape(ax(hull_1), ay(hull_1)),  4, 'JointType','miter');

% 3. get coordinaes of contour
img_Cont = contourc(im2double(IMG_mask), [0.5, 0.5]); 
img_Cont(:, 1) = [];
cxp = img_Cont(1,2:end)'; 
cyp = img_Cont(2,2:end)';
cxp(cxp>size(IMG_mask, 2)) = size(IMG_mask, 2);
cyp(cyp>size(IMG_mask, 1)) = size(IMG_mask, 1);
xdiff_m = [diff(cxp); cxp(end)-cxp(1)]; ydiff_m = [diff(cyp); cyp(end)-cyp(1)];
midx = ( xdiff_m>1 | ydiff_m>1);

% 4. query polyshape with the contour lines' coordinates
TFin1 = isinterior(HULL_image1, cxp, cyp);
cxp(~TFin1 | midx) = []; 
cyp(~TFin1 | midx) = []; 

% 5. use boundary and bwtraceboundary together to ensure points are in right order 
k2 = boundary(cxp, cyp, 0.9);
imgBW=poly2mask(cxp(k2), cyp(k2), size(IMG_mask, 1), size(IMG_mask,2));
bw3 = bwperim(imgBW);
[r0w,c0l] = find(bw3);
[~, jj] = pdist2([c0l,r0w],[1, 1], 'euclidean', 'Smallest', 1);
C = bwtraceboundary(imgBW, [r0w(jj),c0l(jj)], 'NE'); 

% 6. make the shape from the contour vertices that were not outliers!
pgon_fixed = polyshape(C(:,2), C(:,1),  'SolidBoundaryOrientation', 'cw');
pgon_fixed = simplify(pgon_fixed,'KeepCollinearPoints',1);
pgonFixed_simpler = rmholes(pgon_fixed); 

% +++++++++ NOW THE MOVING IMAGE
% 1. make hull
[by, bx]=find(MOVING_mask); 
hull_2 = convhull(bx, by);

% 2. convert hull into polyshape
HULL_image2 = polybuffer(polyshape(bx(hull_2), by(hull_2)), 4, 'JointType','miter'); 

% 3. get coordinaes of contour
MOVING_Cont = contourc(im2double(MOVING_mask), [0.5, 0.5]); 
MOVING_Cont(:, 1) = [];
dxp = MOVING_Cont(1,2:end)'; 
dyp = MOVING_Cont(2,2:end)';
dxp(dxp>size(MOVING_mask, 2)) = size(MOVING_mask, 2);
dyp(dyp>size(MOVING_mask, 1)) = size(MOVING_mask, 1);
xdiff = [diff(dxp); dxp(end)-dxp(1)]; ydiff= [diff(dyp); dyp(end)-dyp(1)];
idx = ( xdiff>1 | ydiff>1);

% 4. query polyshape with the contour lines' coordinates
TFin2 = isinterior(HULL_image2, dxp, dyp);
dxp(~TFin2 | idx) = []; 
dyp(~TFin2 | idx) = []; 

% 5. use boundary and bwtraceboundary together to ensure points are in right order 
k = boundary(dxp, dyp, 0.9);
lesBW=poly2mask(dxp(k), dyp(k), size(MOVING_mask, 1), size(MOVING_mask,2));
bw2 = bwperim(lesBW);
[rw,cl] = find(bw2);
[~, ii] = pdist2([cl,rw],[1, 1],'euclidean', 'Smallest', 1);
B = bwtraceboundary(lesBW, [rw(ii),cl(ii)], 'NE'); 

% 6. make the shape from the contour vertices that were not outliers!
pgon_move = polyshape(B(:,2), B(:,1), 'SolidBoundaryOrientation', 'cw');
pgon_move = simplify(pgon_move,'KeepCollinearPoints',1);
pgonMOVING_simpler = rmholes(pgon_move);

%-----------
% QUERY your turning distance to evaluate if everything is working...
td = turningdist(pgon_move, pgon_fixed);
if td <0.3
    disp('polygons are VERY different, you might have an issue?');
end

%----------------------------------------------------------------------------
%% these polygons are not quite identical to mask. Therefore we need to adjust the corner points
% we want our corners back because we will use them considerably more

cornerIndxMoving = nearestvertex(pgonMOVING_simpler, movingMat(1:4,:));
cornerIndxFixed = nearestvertex(pgonFixed_simpler, fixedMat(1:4,:));

movingM_pgon = pgonMOVING_simpler.Vertices(cornerIndxMoving(1:4, 1), :);
fixedM_pgon = pgonFixed_simpler.Vertices(cornerIndxFixed(1:4, 1), :);

% if the diffference between matrix coordinate and the nearest point on
% polygon is more than 4 pixels, then CPCORR function won't fix it.
diffCorn = movingM_pgon - movingMat(1:4,:);
diffCorn_2 = fixedM_pgon - fixedMat(1:4,:); 
Midx = (diffCorn(:,1).^2+diffCorn(:,2).^2).^0.5 > 4;
Fidx = (diffCorn_2(:,1).^2+diffCorn_2(:,2).^2).^0.5 > 4;
for L = 1:4
    if Midx(L)==1
        movingM_pgon(L,:) = (movingM_pgon(L,:) + movingMat(L,:))./2;
    end
    if Fidx(L)==1
        fixedM_pgon(L,:) = (fixedM_pgon(L,:) + fixedMat(L,:))./2;
    end
end

fixedM = fixedM_pgon;
movingM = movingM_pgon;

% wiggle points so that they register better
movingM = cpcorr(movingM,fixedM,MOVING_gray,IMG_gray); 
fixedM = cpcorr(fixedM,movingM, IMG_gray,MOVING_gray);


% ----------- quick sanity check -----------
sumMoving = sum(movingM,2);
sumFixed = sum(fixedM, 2);
[~, id1] = min(sumMoving); [~, id3] = max(sumMoving);
if id1~=1 || id3 ~=3 || movingM(4, 1)>movingM(2,1) || movingM(4, 2)<movingM(2,2)
disp('error of order: MOVING'); return;
end

[~, fid1] = min(sumFixed); [~, fid3] = max(sumFixed);
if fid1~=1 || fid3 ~=3 || fixedM(4, 2)<fixedM(2,2) || fixedM(4, 1)>fixedM(2,1)
disp('error of order: FIXED'); return;
end
% -----------  end sanity check  -----------



%% Use curve fitting to place evenly spaced points along each edge of the tissue


%% SET NUM POINTS ALONG AN EDGE
pointsPerSide = 15; % multiplied by 4 +9 gives total CP's
%%
%preallocate
evenlydistMoving = zeros(pointsPerSide*4,2, 'double'); 
evenlydistFixed = zeros(pointsPerSide*4,2,'double');
MovingPolynomialVals =zeros(pointsPerSide*4,2,'double'); 
FixedPolynomialVals = zeros(pointsPerSide*4,2,'double');
distancefromcurvetopolygon_m = zeros(pointsPerSide, 1,'double');
distancefromcurvetopolygon_f = zeros(pointsPerSide, 1,'double');

%% ||~~~~-~~~~||~~ START of HUGE LOOP ~~||~~~~-~~~~||~~~~-~~~~||~~~~-~~~~||~~~~-~~~~||~

counter = 1;
for cornerN = 1:4
%corners are numbered 1 -> 4 CW starting in top left. edges are named by the corners they span. 1-2, 2-3, 3-4, and 4-1.    
    if cornerN~=4
        cornerN_plus1 = cornerN+1;
    else
        cornerN_plus1=1;
    end
% make sure corners are in the right order in moving image
    cornsMoving = [movingM(cornerN, 1:2); movingM(cornerN_plus1, 1:2)];
    starting = cornsMoving(2, :);
    ending = cornsMoving(1,:);
    
    st = nearestvertex(pgonMOVING_simpler, starting(1,1), starting(1, 2));
    ed = nearestvertex(pgonMOVING_simpler, ending(1,1), ending(1, 2));

    if ed > st
        PointsToFit = pgonMOVING_simpler.Vertices(st:1:ed, 1:2); 
    else %this should only happen once, 
        PointsToFit = [pgonMOVING_simpler.Vertices(st:end, 1:2); pgonMOVING_simpler.Vertices(1:ed, 1:2)];
    end
    

% repeat with fixed
    cornsFixed = [fixedM(cornerN, 1:2); fixedM(cornerN_plus1,1:2)];
    startingF = cornsFixed(2, :);
    endingF = cornsFixed(1,:);

    st2 = nearestvertex(pgonFixed_simpler, startingF(1,1), startingF(1, 2));
    ed2 = nearestvertex(pgonFixed_simpler, endingF(1,1), endingF(1, 2));
    if ed2 > st2
        PointsToFit_fix = pgonFixed_simpler.Vertices(st2:ed2, 1:2); 
    else %this should only happen once, when the highest index is reached and the numbers restart at 1
        PointsToFit_fix = [pgonFixed_simpler.Vertices(st2:end, 1:2) ;pgonFixed_simpler.Vertices(1:ed2, 1:2)];
    end

    
    %% call the curve fitting script
    pointData  = curveFittingOfTissueBorders(pointsPerSide, cornerN, movingM, fixedM, PointsToFit, PointsToFit_fix, IMG_gray, MOVING_gray);
    
%%
    xy_moving= pointData(1).xyPoints; 
    xy_fixed = pointData(2).xyPoints;
    
    MovingPolynomialVals(counter:counter+pointsPerSide-1,:) = xy_moving(1:end-1,:);
    FixedPolynomialVals(counter:counter+pointsPerSide-1,:) = xy_fixed(1:end-1,:);   
    
%reformat middleGridPoints, which will be at most 9 potential internal control points
% two consecutive sides will need to be reversed order. it is arbitrary which 2
    if cornerN == 3 || cornerN ==4
        midGrid_m{cornerN} = flipud(pointData(1).middleGrid);
        midGrid_f{cornerN} = flipud(pointData(2).middleGrid);
    else
        midGrid_m{cornerN} = pointData(1).middleGrid;
        midGrid_f{cornerN} = pointData(2).middleGrid;
    end

%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=
movingContour = [B(:,2), B(:,1)];
fixedContour =  [C(:,2), C(:,1)];

    for jj = 1:pointsPerSide %first and last corner we just MAKE be the corners
        if jj == 1
            xy_moving(jj, 1:2) = starting;
            xy_fixed(jj, 1:2) = startingF;
            continue;
            
        elseif jj == pointsPerSide
            xy_moving(jj, 1:2) = ending; % the "last" point SHOULD ALWAYS be the next corner point! but we wait to get rid of it til end of loop!
            xy_fixed(jj, 1:2) = endingF; 
            continue;
            
        elseif mod(cornerN, 2) == 1  
            flagg = 1; 
            c=0;
            while flagg == 1
            indx_m = find(movingContour(:,1) == round(xy_moving(jj, 1)));
            
            nPts_m = numel(indx_m); % number of intersections of your xy_moving point with contour
                switch nPts_m
                    case 0
                        c = c+1;
                        xy_moving(jj, 1) = round(xy_moving(jj, 1)+0.6); %shift the x coordinate, then try again
                        flagg = 1; %NOT DONE
                    case 1
                        distancefromcurvetopolygon_m(jj, 1) = pdist2(xy_moving(jj, 1:2), movingContour(indx_m, 1:2), 'euclidean');
                        xy_moving(jj, 2) = movingContour(indx_m, 2); %set the 
                        flagg=2; %DONE
                    otherwise % ie. " > 1 " THIS IS MOST CASES!!!!
                        hits = movingContour(indx_m,1:2);
                        [distances, Id_multi] = pdist2(hits, xy_moving(jj,1:2), 'euclidean', 'Smallest', 1);
                        distancefromcurvetopolygon_m(jj, 1) = distances(1, 1);
                        xy_moving(jj, 2) = hits(Id_multi,2);
                        flagg = 2; %DONE
                end
                if c > 20 && c<51
                    xy_moving(jj,1) = round(xy_moving(jj, 1)-40);
                elseif c>50
                    disp('there is an issue aligning points to contour in moving image');
                    return
                end
            end
% ^ moving            
%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=
% v fixed

            flage = 1;
            c=0;
            while flage ==1
                indx_f = find(fixedContour(:,1) == round(xy_fixed(jj, 1)));
                nPts_f = numel(indx_f);
                switch nPts_f
                    case 0
                        c=c+1;
                        xy_fixed(jj, 1) = round(xy_fixed(jj, 1)+0.6); 
                        flage = 1; %NOT DONE
                    case 1
                        distancefromcurvetopolygon_f(jj, 1) = pdist2(xy_fixed(jj, 1:2), fixedContour(indx_f, 1:2), 'euclidean');
                        xy_fixed(jj, 2) = fixedContour(indx_f,2);
                        flage = 2; %DONE
                    otherwise % ie. " > 1 "
                        hitts = fixedContour(indx_f,1:2);
                        [distys, Id2_multi] = pdist2(hitts, xy_fixed(jj, 1:2), 'euclidean', 'Smallest', 1);
                        distancefromcurvetopolygon_f(jj, 1) = distys(1, 1);
                        xy_fixed(jj, 2) = hitts(Id2_multi,2);
                        flage = 2; %DONE
                end
                if c > 20 && c<51
                    xy_fixed(jj,1) = round(xy_fixed(jj, 1)-40);
                elseif c>50
                    disp('there is an issue aligning points to contour in fixed image');
                    return
                end
            end
  %                                            ^ ^
  % -=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-|%|-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=
  % +-=%=-+-=%=-+-=% this is identical to the above,with x and y coordinates swapped %=-+-=%=-+-
  % -+-=%=-+-=%=-+-=%|-|-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+
  %                  V V          
        elseif mod(cornerN, 2) == 0 %ie QQ = 2 or 4  
            
            flaggy =1;
            c=0;
            while flaggy ==1
            indx_f = find(fixedContour(:,2) == round(xy_fixed(jj, 2)));
            nPts_f = numel(indx_f);
                switch nPts_f
                    case 0
                        c=c+1;
                        xy_fixed(jj, 2) = round(xy_fixed(jj, 2)+0.6); 
                        flaggy = 1; %NOT DONE
                    case 1
                        distancefromcurvetopolygon_f(jj, 1) = pdist2(xy_fixed(jj, 1:2), fixedContour(indx_f, 1:2), 'euclidean');
                        xy_fixed(jj, 1) = fixedContour(indx_f,1);
                        flaggy=2;
                    otherwise % ie. " > 1 "
                        hits = fixedContour(indx_f,1:2);
                        [dists, Id_multi] = pdist2(hits, xy_fixed(jj, 1:2), 'euclidean', 'Smallest', 1);
                        distancefromcurvetopolygon_f(jj, 1) = dists(1, 1);
                        xy_fixed(jj, 1) = hits(Id_multi,1);
                        flaggy=2;
                end
                if c > 20 && c<51
                    xy_fixed(jj,1) = round(xy_fixed(jj, 1)-40);
                elseif c>50
                    disp('there is an issue aligning points to contour in fixed image');
                    return
                end
            end
% ^ fixed             
%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=
 % v moving
            flags = 1;
            c=0;
            while flags == 1
            indx_m = find(movingContour(:,2) == round(xy_moving(jj, 2)));
            nPts_m = numel(indx_m);
                switch nPts_m
                    case 0
                        c=c+1;
                        xy_moving(jj, 2) = round(xy_moving(jj, 2)+0.6); 
                        flags = 1; %NOT DONE
                    case 1
                        distancefromcurvetopolygon_m(jj, 1) = pdist2(xy_moving(jj, 1:2), movingContour(indx_m, 1:2), 'euclidean');
                        xy_moving(jj, 1) = movingContour(indx_m,1);
                        flags=2;
                    otherwise % ie. " > 1 "
                        hits = movingContour(indx_m,1:2);
                        [distance, Id_multi] = pdist2(hits, xy_moving(jj, 1:2), 'euclidean', 'Smallest', 1);
                        distancefromcurvetopolygon_m(jj, 1) = distance(1, 1);
                        xy_moving(jj, 1) = hits(Id_multi,1);
                        flags=2;
                end
            end 
            if c > 20 && c<51
                 xy_moving(jj,1) = round(xy_moving(jj, 1)-40);
            elseif c>50
                 disp('there is an issue aligning points to contour in moving image');
                 return
             end
        end
 %=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=%=-+-=
    end %end looping through points
    clear flag*
    
    %% read out avg residual
    fixed_residuals = sum(distancefromcurvetopolygon_f(:))/pointsPerSide;
    moving_residuals = sum(distancefromcurvetopolygon_m(:))/pointsPerSide;
   
    disp(strcat('FIXED: Avg. distance from point to curve: ', num2str(fixed_residuals)));
    disp(strcat('MOVING: Avg. distance from point to curve: ', num2str(moving_residuals)));

    %% 
    evenlydistMoving(counter:counter+pointsPerSide-1,:) = xy_moving(1:end-1,:);
    evenlydistFixed(counter:counter+pointsPerSide-1,:) = xy_fixed(1:end-1,:);
    
    counter = counter+pointsPerSide;
end
%% ||~~~~-~~~~||~~ END HUGE LOOP ~~||~~~~-~~~~||~~~~-~~~~||~~~~-~~~~||~~~~-~~~~||~~~~-~~~~||~~~~-~

cPointsMoving = cpcorr(evenlydistMoving, evenlydistFixed, MOVING_gray, IMG_gray);
cPointsFix = cpcorr(evenlydistFixed, cPointsMoving, IMG_gray, MOVING_gray);

%% Now use middle Grid points to define the internal control points

mside1 = [midGrid_m{1};fliplr(midGrid_m{2})];
mside2 = [flipud(midGrid_m{3});flipud(fliplr(midGrid_m{4}))];
gridpoints_m = [mside1, mside2];

fside1 = [midGrid_f{1};fliplr(midGrid_f{2})];
fside2 = [flipud(midGrid_f{3});flipud(fliplr(midGrid_f{4}))];
gridpoints_f = [fside1,fside2];

moving_coordinates = solveForGridPoints(gridpoints_m);
fixed_coordinates = solveForGridPoints(gridpoints_f);

cp_moving = [cPointsMoving; moving_coordinates];
cp_fixed = [cPointsFix; fixed_coordinates];

%% Refine control points placement as necessary using this GUI!
[cp_moving, cp_fixed] = visualizeControlPoints_andResetManually(cp_moving, cp_fixed, MOVING_gray, IMG_gray);

 close all force
 figure;
 showMatchedFeatures(MOVING_gray, IMG_gray, cp_moving, cp_fixed);

%% NOW WE USE CPOINTS TO DEFINE 3x Geometric nonrigid transformations

%this is allegedly a great preprocceesing step for multimodal registration
MOVING_gray = imhistmatch(MOVING_gray, IMG_gray);

nP = round(length(cp_moving)*0.9); %number of points to include in the local weighted means
if nP>=7
tform1_lwn = cp2tform(cp_moving, cp_fixed, 'lwm', nP);
tform2_poly2 = cp2tform(cp_moving, cp_fixed, 'polynomial', 2);
tform3_poly3 = cp2tform(cp_moving, cp_fixed, 'polynomial', 3);
else
    disp('issue');
end

imReg1 = imtransform(MOVING_gray,tform1_lwn,'Xdata',[1 size(MOVING_mask,2)],'YData',[1 size(MOVING_mask,1)],'XYscale',1, 'FillValue', 1);
imReg2 = imtransform(MOVING_gray,tform2_poly2,'Xdata',[1 size(MOVING_mask,2)],'YData',[1 size(MOVING_mask,1)],'XYscale',1,'FillValue', 1);
imReg3 = imtransform(MOVING_gray,tform3_poly3,'Xdata',[1 size(MOVING_mask,2)],'YData',[1 size(MOVING_mask,1)],'XYscale',1,'FillValue', 1);

% call GUI to select best nonrigid transformation
choice = evaluate3nonRigidTransformations(imReg1, imReg2, imReg3, IMG_gray);

switch choice
    case 11
    nearlyRegisteredMovingImage = imReg1;
    tform = tform1_lwn;
    case 22
    nearlyRegisteredMovingImage = imReg2;
    tform = tform2_poly2;
    case 33
    nearlyRegisteredMovingImage = imReg3;
    tform = tform3_poly3;
end

MOVINGMaskReg = imtransform(MOVING_mask, tform, 'Xdata',[1 size(MOVING_mask,2)],'YData',[1 size(MOVING_mask,1)],'XYscale',1, 'FillValue', 0);

%turn the warning back on you turned off at the beginning of the function
warning('on', id);

%close anything still open and be sure theyre really closed 
close all force
pause(0.5);

%% FINAL REGISTRATION STEP!! Diffeomorphic demons 
[D, M_Im] = imregdemons(nearlyRegisteredMovingImage, IMG_gray, [500, 320, 100, 20], 'PyramidLevels', 4, 'DisplayWaitbar', false);

sumUnmovedMask = sum(sum(MOVINGMaskReg));
movedMask = imwarp(MOVINGMaskReg, D);

propPixelsLeft = sum(sum(MOVINGMaskReg & movedMask))/sumUnmovedMask; % the smaller the more movement
cc= corrcoef(M_Im,nearlyRegisteredMovingImage);
disp(num2str(cc), num2str(propPixelsLeft));

%% Visualization #3

f3 = uifigure;
gl_3 = uigridlayout(f3, [3,3]);
gl_3.RowHeight = {'1x',20};
butClose = uibutton(gl_3,'push', ...
    'Text','Close The Visualization?',...
    'ButtonPushedFcn', @(~,~) butCloseFcn);

butClose.Layout.Row = 2;butClose.Layout.Column = 2;

axImgs = uiaxes(gl_3);  title(axImgs, 'Fixed and Moving Images')
axMasks = uiaxes(gl_3); title(axMasks, 'Fixed and Moving MASKS')
axChange = uiaxes(gl_3); title(axChange, 'Moving masks before and after demons algo')
axChange2 = uiaxes(gl_3); title(axChange2, 'grayImages before and after demons algo')

axChange.Layout.Column = 1; axImgs.Layout.Column = 3; axMasks.Layout.Column = 2;
axChange.Layout.Row = [2, 3]; axImgs.Layout.Row = [2, 3]; axMasks.Layout.Row = 2;
axChange2.Layout.Column = 1; axChange2.Layout.Row = 1;

%f3.Visible = 'on';
imshowpair(M_Im, nearlyRegisteredMovingImage, 'falsecolor', 'ColorChannels', [2,2,1], 'Parent', axChange2, 'scaling', 'none');
imshowpair(M_Im, IMG_gray, 'falsecolor', 'ColorChannels', [1,2,2], 'Parent', axImgs, 'scaling', 'none');
imshowpair(movedMask, IMG_mask,'falsecolor', 'ColorChannels', [2,1,2], 'Parent', axMasks, 'scaling', 'none');
imshowpair(MOVINGMaskReg, movedMask, 'falsecolor', 'ColorChannels', [2,2,1], 'Parent', axChange, 'scaling', 'none');
drawnow ;

uiwait
close all force

% M_Im and moved Mask are output variables for the function = they get sent
% back to registration part 1 where they are saved!!
end




function choice = evaluate3nonRigidTransformations(imReg1, imReg2, imReg3, IMG_gray)

hFig = uifigure(...
    'Name', 'Registration', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'Toolbar', 'none',...
    'Visible', 'off');

set(hFig, 'units', 'pixels');
pos = get(hFig, 'Position');
pos(3:4) = [800 600];
set(hFig, 'Position', pos);

%obj.Handles.Figure = hFig;
gl = uigridlayout(hFig,[3, 3],...
    'RowHeight', {'1x',40 , 40});

ax1 = uiaxes('Parent', gl);
ax1.Layout.Row = 1;
ax1.Layout.Column = 1;

ax2 = uiaxes('Parent', gl);
ax2.Layout.Row = 1;
ax2.Layout.Column = 2;

ax3 = uiaxes('Parent', gl);
ax3.Layout.Row = 1;
ax3.Layout.Column = 3;

im1 = imfuse(imReg1, IMG_gray, 'falsecolor', 'scaling', 'none', 'ColorChannels', [1,2,2]);
im2 = imfuse(imReg2, IMG_gray, 'falsecolor', 'scaling', 'none', 'ColorChannels', [1,2,2]);
im3 = imfuse(imReg3, IMG_gray, 'falsecolor', 'scaling', 'none', 'ColorChannels', [1,2,2]);

imshow(im1,'Parent', ax1, 'Border', 'tight');
imshow(im2,'Parent', ax2, 'Border', 'tight');
imshow(im3,'Parent', ax3, 'Border', 'tight');

title(ax1, 'LWM method');
title(ax2, 'Polynomial, deg 2');
title(ax3, 'Polynomial, deg 3');

lbl1 = uilabel(gl, 'Text', num2str(corr2(imReg1, IMG_gray)));
lbl1.Layout.Column = 1;
lbl2 = uilabel(gl, 'Text', num2str(corr2(imReg2, IMG_gray)));
lbl2.Layout.Column = 2;
lbl3 = uilabel(gl, 'Text', num2str(corr2(imReg3, IMG_gray)));
lbl3.Layout.Column = 3;

lbl1.Layout.Row = 2; lbl2.Layout.Row = 2; lbl3.Layout.Row = 2;

btn1 = uibutton(gl, 'push', 'Text', 'LWM', 'ButtonPushedFcn', @button1Callback);
btn2 = uibutton(gl, 'push', 'Text', 'polynomial, deg2','ButtonPushedFcn', @button2Callback);
btn3 = uibutton(gl, 'push', 'Text', 'polynomial, deg3','ButtonPushedFcn', @button3Callback);

btn1.Layout.Row = 3;
btn1.Layout.Column = 1;
btn2.Layout.Row = 3;
btn2.Layout.Column = 2;
btn3.Layout.Row = 3;
btn3.Layout.Column = 3;

set(hFig, 'Visible', 'on');

uiwait;
% retrieve app data holding user selection from GUI
choice = getappdata(0, 'mySelection');

%reset app data for next time!
setappdata(0, 'mySelection', []);
end

function button1Callback(~, ~)
    setappdata(0, 'mySelection', 11);

    uiresume;

end

function button2Callback(~, ~)
    setappdata(0, 'mySelection', 22);
    
    uiresume;

end

function button3Callback(~, ~)
    setappdata(0, 'mySelection', 33);
    
    uiresume;

end

function butCloseFcn(~,~)
uiresume;
end

function [cp_moving, cp_fixed] = visualizeControlPoints_andResetManually(cp_moving, cp_fixed, MOVING_gray, IMG_gray)

close all force

ff = figure;
imshowpair(MOVING_gray, IMG_gray, 'blend');
% Define the color order for the plots
colors = {'r', 'g'};
cp = [cp_moving; cp_fixed];
sz = size(cp_moving, 1); %this necessarily is the same value as size(cp_fixed, 1)
% Plot the control points on both images
hold on;
plot(cp(1:sz,1), cp(1:sz,2), [colors{1} '*'], 'MarkerSize', 10);
plot(cp(sz+1:2*sz,1), cp(sz+1:2*sz,2), [colors{2} '*'], 'MarkerSize', 10);
hold off;

disp('Please click on any misaligned control points to adjust their position. Press any key when finished.');

while true
    [x, y, button] = ginput(1);
    if button ~= 1 || size([x,y], 1)==0 || size([x,y], 2) ==0 % exit loop if button other than left-click is pressed
        return;
    else
    
    % Find the nearest control point to the clicked position
    try
    distances = sqrt(sum(bsxfun(@minus, [x y], cp).^2, 2));
    catch
        return
    end
    [~, idx] = min(distances);
    
    
    % Determine which set of control points the selected point belongs to
    if idx <= sz
        curr_cp = cp(1: sz, 1:2);
        flag = 1;
        %  curr_h = h_moving;
    elseif idx > sz
        curr_cp = cp(sz+1:end, 1:2);
        flag = 2;
        %curr_h = h_fixed;
        idx = idx - sz;
    end
    oldx = curr_cp(idx, 1);
    oldy = curr_cp(idx, 2);
    
    
    cla;
    imshowpair(MOVING_gray, IMG_gray, 'blend');
    %instead of deleting the point and messing up our index values. we just
    %move it out of frame,
    if flag == 1
        cp(idx, 1:2) = [-10, -10];
    else
        cp(idx+sz, 1:2)= [-10, -10];
    end
    
    %replot without that 1 point
    hold on
    plot(cp(1:sz,1), cp(1:sz,2), [colors{1} '*'], 'MarkerSize', 10);
    plot(cp(sz+1:2*sz,1), cp(sz+1:2*sz,2), [colors{2} '*'], 'MarkerSize', 10);
    %replace the old point a blue marker as filler
    hOld = plot(oldx, oldy, 'bo', 'MarkerSize', 10);
    hold off
    
    % Prompt the user to adjust the control point's position
    new_pos = ginput(1);
    ff.Visible = 'off';
    [ii, ~] = find(cp<0, 1, 'first'); % find the first negative value of cp, whould should be your point
    %assin the new value of the replaced coordinate into cp
    cp(ii, :) = new_pos(1:2);
    
    delete(hOld);
    cla; imshowpair(MOVING_gray, IMG_gray, 'blend');
    hold on;
    plot(cp(1:sz,1), cp(1:sz,2), [colors{1} '*'], 'MarkerSize', 10);
    plot(cp(sz+1:2*sz,1), cp(sz+1:2*sz,2), [colors{2} '*'], 'MarkerSize', 10);
    hold off;
    ff.Visible = 'on';
    end
    clear x y
end
cp_moving = cp(1:size(cp_moving, 1),1:2);
cp_fixed = cp(size(cp_moving, 1)+1:end,1:2);
end

