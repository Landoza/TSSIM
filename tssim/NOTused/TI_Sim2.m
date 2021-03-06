function [cat_probs,boundaries, lobe_indicator_map, TIangle]=TI_Sim2(sim_area,nObSimTI, nTI,nObSimPF,start_point,angles, snesim_lobe_num,numCat,center_point,chan_detrend_totalL_to_width_cdf,chan_h,width_cdf,lobe_length_cdf,lobe_max_thick, g, ML_output_path,g2s_code_path, ML_code_path,Figures_output_path, verbose,condition_flag, write_flag, plot_flag)

%lobe_index_map=zeros(g.ny,g.nx);
angle_list=zeros(nObSimTI,1);
%startPT_list=zeros(nObSimTI,2);
lobe_num=1;
while lobe_num<=nObSimTI
    angle_list(lobe_num)=angles(ceil(rand*size(angles,1)))*pi/180;
    lobe_num=lobe_num+1;
end
pick=ceil(rand*nObSimTI);
angle_pick=angle_list(pick);
TIangle=angle_pick*180/pi;
%angle_diffs=abs(angle_pick-angle_list);

% Now generate the training images based on the start points chosen above

% These will store the depositional and erosional thickness and indicator maps for all the object-based simulations
TI_thick_cube=zeros(g.ny, g.nx, nTI);
TI_indicator_cube=zeros(g.ny, g.nx, nTI); 
lobe_n=1;
center_point1(1) = g.nx-center_point(1);
center_point1(2) = g.ny-center_point(2);
start_point1(1) = g.nx-start_point(1);
start_point1(2)= g.ny-start_point(2);
while lobe_n<=nTI
    % first generate the new lobe
    lobe_inside=0;
    %checking if lobe is inside or not (90%) of the simulation area.
    while (lobe_inside==0)
        [lobe_thick_map,lobe_ind_map]=lobe_generator(start_point,center_point,angles,width_cdf, lobe_length_cdf,lobe_max_thick, g,verbose);     
            ind_lobe=length(find(lobe_ind_map)~=0);
            ind_lobe_inside=length(find(lobe_ind_map.*sim_area)~=0);
            ratio=ind_lobe_inside/ind_lobe;
        if ratio>0.93
            lobe_inside=1;   
        end
    
    end
    % then generate the channel starting at the origin and connecting to the lobe
    d_chan=centerline_generator(center_point1,start_point1,g); %generate channel centerline
    [across_dist]=find_nearest_point(d_chan,g,verbose);
    [chan_thick,chan_ind]=channel_shape_generator(across_dist,chan_detrend_totalL_to_width_cdf,chan_h,d_chan,g);
    % top_main_chan_thick= -1*channel_shape_generator(across_dist,main_chan_w,top_chan_h,d_main_chan,g);
    ind_map=lobe_ind_map+fliplr(flipud(chan_ind));
    % Add the channel to the thickness map
    thick_map=lobe_thick_map+fliplr(flipud(chan_thick));
    thick_map(find(ind_map>1))=lobe_thick_map(find(ind_map>1));
    %max(max(thick_map));
    %lobe_max_thick
    TI_thick_cube(:,:,lobe_n)=thick_map;
    TI_indicator_cube(:,:,lobe_n)=ind_map;
    lobe_n=lobe_n+1;
end
TI_indicator_cube(find(TI_indicator_cube~=0))=1;

% Make categorical thicknesses so that we can use them in snesim. 

%maxTC=max(max(max(TI_thick_cube)));
maxTC=lobe_max_thick+.0001;  % Added a bit because there seems to be some numerical thing creating errors.
minTC=min(min(min(TI_thick_cube)));
cat_hist_num=zeros(1,numCat);
%ind_hist_eros=zeros(1,2);   % histogram of erosion indicator

% This is a vector of numeric thicknesses that bound each category (for 4
% categories, with zeros as category 1, boundaries=[-1.2 0 0 .2 1.5], for example
% The boundaries are determined from the TI's only. Then any subsequent
% simulations for making the indicator maps (where hard data is not
% assigned) use those boundaries. In fact, since indicator only, the
% boundaries don't even matter, but they could eventually if we're going to
% use pfields. 

%boundaries=zeros(1,numCat+1); 
boundaries=zeros(1,numCat); 

cat_thick_cube=100*ones(g.ny, g.nx, nTI);
small=minTC;
boundaries(1)=small;

% This is the code to use if there are negative values in the thicknesses
% % Make category 0 for all negative values (erosion)
% cat_thick_cube(find((TI_thick_cube<0)&(TI_thick_cube>=small)))=0;
% cat_hist_num(1)=length(find(cat_thick_cube==0));
% boundaries(2)=0;    
% 
% % Make category 1 for all zero values (no lobe)
% cat_thick_cube(find(TI_thick_cube==0))=1;
% cat_hist_num(2)=length(find(cat_thick_cube==1));
% 
% small=0;    
% boundaries(3)=0.01;% Arbitrarily assign a deposition depth for the fine-grained facies. This can be changed based on time of deposition (which can be random) and distance from sediment source.
% for n=2:numCat-1
%     large=(n-1)*maxTC/(numCat-2);
%     boundaries(n+2)=large;
%     cat_thick_cube(find((TI_thick_cube<=large)&(TI_thick_cube>small)))=n;
%     cat_hist_num(n+1)=length(find(cat_thick_cube==n));
%     small=large;
% end
% check=find(cat_thick_cube>98);

% If there are no negative values in the thicknesses:
 
% boundaries(3)=0.01;% Arbitrarily assign a deposition depth for the fine-grained facies. This can be changed based on time of deposition (which can be random) and distance from sediment source.
% In this case, boundaries are only the maximum thicknesses for each
    % category (zero is not included)
boundaries(1)=.02;
% % Make category 0 for all zero values (no lobe), but assign the thickness
    % above (0.01)
cat_thick_cube(find(TI_thick_cube==0))=0;
cat_hist_num(1)=length(find(cat_thick_cube==0));
% ind_hist_eros(2)=length(find(TI_eros_indicator_cube~=0));
% ind_hist_eros(1)=length(find(TI_eros_indicator_cube==0));

small=0;
for n=1:numCat-1    % This is the actual snesim category number
    large=(n)*maxTC/(numCat-1);
    boundaries(n+1)=large;
    cat_thick_cube(find((TI_thick_cube<=large)&(TI_thick_cube>small)))=n;
    cat_hist_num(n+1)=length(find(cat_thick_cube==n));
    small=large;
end
%check=find(cat_thick_cube>98);
%TI_thick_cube(check);

for lobe=1:nTI
    figure;imagesc(cat_thick_cube(:,:,lobe));
end


tot_dat=sum(cat_hist_num);
cat_probs=cat_hist_num/tot_dat;
% eros_ind_probs=ind_hist_eros/tot_dat    % These are the probabilities of non-erosion and erosion, respectively
% eros_ind_probs(1)=1.0-eros_ind_probs(2);    % just to be sure

prefix=strcat(num2str(snesim_lobe_num),'_');

for jj=1:nTI
   suffix=num2str(jj);
   cat_thickness_map=cat_thick_cube(:,:,jj);    % Pick out the categorical TI from the stack of potential TI's
 %  cat_eros_map=TI_eros_indicator_cube(:,:,jj);
   if write_flag==1
        write_gslib_grid(strcat([ML_output_path 'cat_thickness_map_'],prefix,suffix,'.dat'),cat_thickness_map,g,2);
        convert_to_binary('geoeas2sgems.par',strcat([ML_output_path 'cat_thickness_map_'],prefix,suffix,'.dat'),strcat([ML_output_path 'TI_'],prefix, suffix, '.out'),g2s_code_path,ML_code_path,1,'grid',g);
%         write_gslib_grid(strcat([opath_output 'cat_eros_map_'],prefix,suffix,'.dat'),cat_eros_map,g,2);
%         convert_to_binary('geoeas2sgems.par',strcat([opath_output 'cat_eros_map_'],prefix,suffix,'.dat'),strcat([opath_output 'TI_eros_'],prefix, suffix, '.out'),g2s_code_path,ML_code_path,1,'grid',g);
   end
    if snesim_lobe_num<=2 && plot_flag==1;  % Show and save the TIs from the first two lobe simulations
      fTI=figure;
      imagesc(g.x,g.y,flipud(cat_thickness_map));
      title('Categorical channel-lobe thickness map (TI)');
      colorbar;
      xlabel('x [m]');
      ylabel('y [m]');
      axis xy;
      axis equal;
      saveas(fTI,strcat(Figures_output_path,'TI_Lobe',num2str(jj)),'jpg');
      
      fTI=figure;
      imagesc(g.x,g.y,flipud(TI_thick_cube(:,:,jj)));
      title('Channel-lobe thickness map (TI)');
      colorbar;
      xlabel('x [m]');
      ylabel('y [m]');
      axis xy;
      axis equal
      saveas(fTI,strcat(Figures_output_path,'TI_Thickness',num2str(jj)),'jpg')
   
    end
end
%-------------------------------------------------------
% Now generate a series of lobes within the angle range above to determine
    % allowable lobe area
lobe_nm=1;
while lobe_nm<=nObSimPF
  
lobe_inside=0;
    while (lobe_inside==0)
        [lobe_thick_map,lobe_ind_map]=lobe_generator(start_point,center_point,angles,width_cdf, lobe_length_cdf,lobe_max_thick, g,verbose);     
            ind_lobe=length(find(lobe_ind_map)~=0);
            ind_lobe_inside=length(find(lobe_ind_map.*sim_area)~=0);
            ratio=ind_lobe_inside/ind_lobe;
        if ratio>0.9
            lobe_inside=1;   
        end
    
    end
    d_chan=centerline_generator(center_point1,start_point1,g); %generate channel centerline
    [across_dist]=find_nearest_point(d_chan,g,verbose);
    [chan_thick,chan_ind]=channel_shape_generator(across_dist,chan_detrend_totalL_to_width_cdf,chan_h,d_chan,g);
    % top_main_chan_thick= -1*channel_shape_generator(across_dist,main_chan_w,top_chan_h,d_main_chan,g);
    

        % Only need indicators to see where lobes are:
        PF_ind_map=lobe_ind_map+fliplr(flipud(chan_ind));
        %doubles=find(PF_ind_map>1);
        %PF_ind_map(doubles)=1;
        PF_indicator_cube(:,:,lobe_nm)=PF_ind_map;

%         figure;
%         imagesc(g.x,g.y,PF_ind_map);
%         title(strcat('Individual Lobe Indicator Map to test for  ',num2str(nObSimPF+nTI),' Object-based Simulations'));
%         colorbar;
%         xlabel('x [m]');
%         ylabel('y [m]');
%         axis xy;
%         axis equal

        lobe_nm=lobe_nm+1;
    end
PF_indicator_cube(find(PF_indicator_cube~=0))=1;

lobe_indicator_map=sum(PF_indicator_cube,3)+sum(TI_indicator_cube,3);
lobe_indicator_map(find(lobe_indicator_map~=0))=1;

if plot_flag==1
fTI=figure;
imagesc(g.x,g.y,flipud(lobe_indicator_map));
title(strcat('Lobe Indicator Map for  ',num2str(nObSimPF+nTI),' Object-based Simulations'));
colorbar;
xlabel('x [m]');
ylabel('y [m]');
axis xy;
axis equal;
saveas(fTI,strcat(Figures_output_path,'Sim_Area',num2str(jj)),'jpg');
end



