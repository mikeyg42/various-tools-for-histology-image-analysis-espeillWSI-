function [mySettings] = setts_and_prefs

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%% directories + file locations %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%set these directory locations for your local data storage

% SEGMENTATION draws from "directOfImages" and saved saveDestination_adjImages 
% the corrresponding masks are saved in saveDestination_foregroundMask.

% REGISTRATION requires 2 images and 2 masks, which it usually pulls out of
% the 2 folders SEGMENT saved into.

 % ======================================================================= %  

% Directories!:

directOfImages          = '/Users/mikeglendinning/Desktop/processedMSimages/';
saveSegm_adjImages      = '/Users/mikeglendinning/Desktop/processedMSimages/'; 
saveSegm_foregroundMask = '/Users/mikeglendinning/Desktop/processedMSimages/';
saveRegistraion         = '/Users/mikeglendinning/Desktop/processedMSimages/';
saveDestination_rois    = '/Users/mikeglendinning/Desktop/processedMSimages/';

 % ======================================================================= %  

% File Formats:
% define the file formats of images currently in 'input', and desired format of output

% INPUT_rawdata is the ONLY var that can be a list of multiple formats. 

    input_rawdata_format            = {'.tiff','.tif'}; % optionlly can be a list (specified as char array)

    segm_saveFMT_adjImage           = '.tiff'; 
    segm_saveFMT_foregroundMask     = '.png'; 

    reg_saveFMT_adjImage            = segm_saveFMT_adjImage;
    reg_saveFMT_foregroundMask      = segm_saveFMT_foregroundMask;

    chooseROI_saveFMT_allROIs       = '.tiff';
    chooseROIS_saveFMT_roiLocations = '.png'; 

% ======================================================================== %

%% You can opt to just process one particular image, in lieu of an entire dir. 
% The first step of every one of these 3 programs is to create an image datastore containing the 
% entirety of the directory specied ab ove as "directOfImages". It will loop through that
% directory until its exhausts every file in it....BUT in the spirit of flexibility...
% you can override that by changing "loopThroughDirectory" to false. Then, indicate the identiers for
% the specific sample you'd like to process: sample ID and stain ID(s)
% - Ensure that there are not multiple files with the same identifiers indicated

doNOTloopThroughDirectory_justUseThis = false;
% This works for ChoosingROIs and Segmentation. 

  %1.
     sampleID      = '4817'; % =========================================== %
  %2.
     stainID       = 'cd31'; % =========================================== %
  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%% Customizing function features and pararmeters %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Segmentation -- %note that in the .m file for 

    % a 1.25GB image takes ~1-2mins after it has been scaled down 2.8
        seg_scaleFactor = 2.4;

    % save scaled downimage? or try to resample image back to original size before save?
        seg_resizeBig = false;
    
    % after you have processed a raw file, the adjusted image will be saved. 
        % Would you like to delete it? If your raw data dir is copied locally, it might help...
        seg_deleteYES = false;
    
    % in the event that one file in your rawdata directory has a mask already in the save
    % folder, do you want to double check it or just skip?
        seg_doubleCheckSavedMasks = true;
    
    % optional - include a prefix identifier for saved files. It must start with an underscore!
         seg_versionID = '_v2';  %can also be left blank with char() 

        
 % ======================================================================= %  

% Registration  --

    % StainIDs for moving and fixed
        reg_movingID = 'CD31';
        reg_fixedID  = 'PLP' ;

    % Include optional step where a GUI opens to mediate manual coarse adjust rotation??
        % This is necessary if and only if your images might be > 90degrees off
        reg_coarseAdj = true;

    % Opt to include another optional step in which a GUI opens enabling the
        % manually adjustment of the binary mask of your foreground segmentation.  
        % I incorporated this because sometimes an image has rip, tear, 
        % or some other quirk which hinder registration. By dragging the mask to approximately
        % the shape of the tissue without a rip, registration works much better.
        reg_manPtRepositioning = false;

    % scale factor #2. If you downsampled images before segmentation and did not upsample
      % before saving, then likely you don't need any resampling here 
      % (in this event, indicate no resampling by setting this = 1.0)
        reg_scaleFactor2 = 1.4; 
    
    % Set how many control points we assign to each of the 4 side of each tissue! 
         % (In total we will have this:
         %               numel(controlPoints) = 9 + 4*reg_numCPointsPerSide)
        reg_numCPointsPerSide = 22;

 % ======================================================================= %  
 
 % Choosing ROIs --

    % How many ROIs to pick out?
        roi_numROIs = 4;

    % Size of each ROI's? Provide the dimensions in pixels, as a vector: [height, width]
        % Do not indicate an roi_size adjusted for any resampling, that will happen automatically,
        % instead the dimensions should reference the pixel grid of your RAW input image.
        roi_sizeROI = [450,350];

    % Sampling method- I have included two procedures for the spatial sampling of the
    % whole slide image. 
        % #1 "random" sampling without allowing overlap. Also, this method uses a semi-automated 
            % frame-work (kind of like a human-on-the-loop) where ROI's can be accepted/rejected by user. 
        % #2 (NOT FUNCTIONAL YET) is a varient of systematic sampling leveraging circle packing. Structure 
            % is achieved by tiling the entire tissue in nonoverlapping, size-bounded cirlces, an application of 
            % an ancient geometry problem generally called "circle packing"). 
        roi_method = 'semiAuto_randomSampling' ;% or, 'circlePacking'; <-- NOT YET, circles are broken
        
    % Rotation allowed for ROI's? If desired, into both methods I have included the
    % possibility of expanding the domain of potential ROIs to extract to enable each ROI
    % 360deg of rotation. 
    % rotation
        roi_YesRotation = true; % this applies to either of the 2 methods. 
            %^^ NOTE: rotation requires interpolation, which can lead to spurrious signals and affect
            %invariant feature calculations. Use with caution.

    % [optional: CirclePacking only] Override the preset range of radii for the Circle Packing algorithm? 
    % Currrent implmentation has the lower bound of max(roi_sizeROI) and the upper bound of
    % max(roi_sizeROI)*sqrt(2);
        roi_newRadiusBounds = []; % or [lowRadl, highRad]
    
    % Compounding masks? inlcude them here, and ROI will be sampled from their union. White should be foreground. 
    %by compounding I mean multiple for individual images
        % TO OMIT - write 'none' below. 
        % TO INCLUDE compound masks, write the full path where additional masks will be. If multiple,
        % make this into a cell array
        roi_additionalMasks = 'none'; % or {'path/to/additionalmask1', 'path/to/additionalmask2',...}

% ======================================================================== %


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%% Don't change anything below here %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    

% =========== #1 fileDirectories ========================================= %

fileDirectories = struct('rawData', directOfImages,...
                         'saveSegm_adjImages', saveSegm_adjImages,...
                         'saveSegm_foregroundMask', saveSegm_foregroundMask, ...
                         'saveRegistraion', saveRegistraion,...
                         'saveDestination_rois', saveDestination_rois);

% ensures that each path in this array has a terminal '/'
fileDirectories = structfun(@(x) strcat(x, '/'), fileDirectories, 'UniformOutput', false);
fileDirectories = structfun(@(x) replace(x, '//', '/'), fileDirectories, 'UniformOutput', false);


% =========== #2 fileFORMATS ============================================= %

fileFMTS = struct(  'rawDataFMT', [],...
                    'segm_saveFMT_adjImage', segm_saveFMT_adjImage, ...
                    'segm_saveFMT_foregroundMask', segm_saveFMT_foregroundMask,...
                    'reg_saveFMT_adjImage', reg_saveFMT_adjImage,...
                    'reg_saveFMT_foregroundMask', reg_saveFMT_foregroundMask,...
                    'chooseROI_saveFMT_allROIs', chooseROI_saveFMT_allROIs,...
                    'chooseROIS_saveFMT_roiLocations', chooseROIS_saveFMT_roiLocations);

fileFMTS(1).rawDataFMT = input_rawdata_format; 
% This variable is set off on its own down here so to preempt a sneaky and pernicious 
% pitfall of setting structural array fields to char arays.... Consider this example: 
    %           s = struct('rawDataFMT', {'.ext1', '.ext2'},...) 
    % however much you may want this to be interpretted as: 
    %           s(1).files = {'.ext1', '.ext2'}. 
    % as written, it means:
    %           s(1).files = '.ext1'; 
    %           s(2).files = '.ext2'; 


% =========== #3 pickME (specific sample choices) ======================== %

   pickME = struct('sampleID', [],'stainID', []);

if doNOTloopThroughDirectory_justUseThis
   pickME = struct('sampleID', sampleID, 'stainID', stainID);
end


% =========== #4 (3x) Project Specific Params ============================ %


 chooseROI = struct('numROIs', roi_numROIs, ...
                    'sizeROI', roi_sizeROI,...
                    'roi_method',roi_method,...
                    'roi_YesRotation', roi_YesRotation,...
                    'roi_additionalMasks', roi_additionalMasks, ...
                    'roi_newRadiusBounds', roi_newRadiusBounds);

       reg = struct('movingID', reg_movingID, ...
                    'fixedID', reg_fixedID,...
                    'reg_coarseAdj',reg_coarseAdj, ...
                    'reg_manPtRepositioning', reg_manPtRepositioning,...
                    'reg_scaleFactor2', reg_scaleFactor2, ...
                    'numCPointsPerSide', reg_numCPointsPerSide);
        
       seg = struct('seg_scaleFactor', seg_scaleFactor, ...
                    'seg_resizeBig', seg_resizeBig,...
                    'seg_deleteYES', seg_deleteYES, ...
                    'seg_doubleCheckSavedMasks', seg_doubleCheckSavedMasks);


% ======================================================================== %
% ================= Load everything into 1 structure  ==================== %
% ======================= called: "mySetting" ============================ %
% ======================================================================== %


mySettings = struct('directories', fileDirectories,...
                    'fileFormats', fileFMTS,...
                    'seg',         seg, ... 
                    'chooseROI',   chooseROI,...
                    'reg',         reg, ...
                    'pickME',      pickME, ...
                    'savePrefs',   struct('seg_versionID', seg_versionID));


% ======================================================================== %
 end % =================================================================== %
% ======================================================================== %

