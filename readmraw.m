function [im, cam_meta] = readmraw(filename, frames, frames_definition)

% %% Function inputs
% filename : path to the duplicately named 'filename.cih' and 'filename.mraw'
% or structure containing metadata outputted by parse_cih.m
% frames [OPTIONAL] : frames to save, frame definition defined next
% If frames is not input, then pulls out whole movie as images
% Frames_definition [OPTIONAL], {'file'(default),'trigger'}
% Written by Jorn Cheney; updated 2018 7-July

% Updates : by default frames runs from 1:cam_meta.TotalFrame to match Photron supplied
% mraw reader and VideoReader format. However, frames_definition can be set
% to 'trigger' in order to define frames input relative to the .cih
% definition.
% Now compatibile with 8, 12, and 16- bit formats. 
%
% 12 bit data is now read in as 8bit and then bit-shifted to
% give 12 bits. On Windows reading in little endian is much faster than big
% endian. Therefore 12 bit data is read in as little endian and read ordered
% afterwards using swapbtyes. These two changes give approx 10x improvement
% in read times. - SMW 11th July 2018
%
% Also now outputs cam_meta from cih file
%
% Updated by Simon Walker 2018 9-July & JAC 10-July
%
% Note differences in luminance exist when comparing the output to PFV. 
% This is because as of PFV 3.6.6, camera models UX/WX/AX/Multi/ & some SA-Zs
% apply noise reduction in PFV. I have requested a toggle button to be add
% to PFV to allow users to turn this noise reduction on and off. - JAC Feb 3rd 2017
% N.B. AX200 values appear to be the same on PFV as when read in using this
% function - SMW 9th July 2018

%% Use parse_cih to extract metadata if needed
if ischar(filename)
    %metadata in general (now given as optional output)
    cam_meta=parse_cih([filename '.cih']);
elseif isstruct(filename)
    cam_meta=filename;
    filename=cam_meta.filename;
else
    error('first input must be filename or camera metadata')
end

%% Determine if cih and mraw files exist
if  exist([filename '.mraw'],'file')~=2
    error(['Could not find: ' filename '.mraw'])
elseif exist([filename '.cih'], 'file')~=2 && exist([filename '.cihx'], 'file')~=2
    error(['Could not find: ' filename '.cih'])
end

%% Set parameters based on file format
if cam_meta.ColorBit==8
    precision='*uint8';
    output_type='uint8';
    bytesPerPix=1; % number of bytes (8 bits) per pixel, needed for offset

elseif cam_meta.ColorBit==12
    precision='*uint8'; % read 12bit as 8bit and then convert
    output_type='uint16';
    bytesPerPix=1.5;

elseif cam_meta.ColorBit==16
    precision='*uint16';
    output_type='uint16';
    bytesPerPix=2;

else
    error('mraw not encoded in 8, 12 or 16 bits and in monochrome')
end
%% Handle various input quantities
%define definition for frames as relative to file
if nargin<3
    frames_definition='file';
end
%if no specific "frames" requested, read whole file
if nargin==1
    frames=1:cam_meta.TotalFrame;
end
%if definition is relative to trigger, calculate position of frames in file
if strcmp(frames_definition,'trigger')
    frames = frames-cam_meta.StartFrame+1;
end
%if bad input for definition
if ~strcmp(frames_definition,'trigger') && ~strcmp(frames_definition,'file')
    error(['Third input must be either ''trigger'' or ''file'', not: ' num2str(frames_definition)])
end
%if any requested frames are out of bounds
if     any(frames<1) || any(frames>cam_meta.TotalFrame)
    error(['requested frames must be 1 <= frame <= ' num2str(cam_meta.TotalFrame)])
end    

%% Parse information about acquisition and saving
im_width = cam_meta.ImageWidth;
im_height= cam_meta.ImageHeight;

%number of pixels per frame
numPix=im_width*im_height;

%% Extract frames from mraw file
%open file
mraw_file=fopen([filename '.mraw'],'r');

%% Read .mraw and format into 3D Matrix [image_width,image_height,frames]
if nargin==2 && ~isequal(frames,1:cam_meta.TotalFrame)

    im=zeros([im_height,im_width,length(frames)],output_type);
    for f=1:length(frames)

        fseek(mraw_file, bytesPerPix*numPix*(frames(f)-1), 'bof');

        if cam_meta.ColorBit==12
            data_8b = fread(mraw_file, numPix*1.5, precision);
            data_16b=uint16(swapbytes(data_8b));

            pad  = ceil(length(data_16b) / 3) * 3 - length(data_16b);
            data_16b_padded = cat(1, data_16b, zeros(pad, 1, 'uint16'));
            data_16b_padded = reshape(data_16b_padded, 3, []).';

            data_12b = [bitshift(data_16b_padded(:, 1), 4) + bitshift(data_16b_padded(:, 2), -4), ...
                        bitshift(rem(data_16b_padded(:, 2), 16), 8) + data_16b_padded(:, 3)];

            vid_frame=reshape(data_12b',[im_width,im_height]);

        else
            vid_frame=fread(mraw_file,[im_width,im_height],precision); %Read in bits at specified precision
        end

        im(:,:,f)=vid_frame';

    end

else
    fseek(mraw_file, 0, 'bof');

    if cam_meta.ColorBit==12

        data_8b = fread(mraw_file, inf, precision);
        data_16b=uint16(swapbytes(data_8b));

        pad  = ceil(length(data_16b) / 3) * 3 - length(data_16b);
        data_16b_padded = cat(1, data_16b, zeros(pad, 1, 'uint16'));
        data_16b_padded = reshape(data_16b_padded, 3, []).';

        data_12b = [bitshift(data_16b_padded(:, 1), 4) + bitshift(data_16b_padded(:, 2), -4), ...
                 bitshift(rem(data_16b_padded(:, 2), 16), 8) + data_16b_padded(:, 3)];

        % manual bit-shift, just kept for reference
%         video = [data(:, 1) * 16 + data(:, 2) / 16, ...
%                 rem(data(:, 2), 16) *256 + data(:, 3)];

        N = [im_width im_height length(frames)];
        im=permute(reshape(data_12b',N),[2 1 3]);

    else
        vid_segments=fread(mraw_file,inf,precision); %Read in bits at specified precision and format
        N = [im_width im_height length(frames)];
        im=permute(reshape(vid_segments,N),[2 1 3]);
    end

end

fclose(mraw_file);