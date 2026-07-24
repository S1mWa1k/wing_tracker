function cih_struct = quick_parse_cihx(fname)
% save temp_parse_cih
% clear
% fname='C:\Users\swal-admin\Dropbox\MATLAB_DROPBOX\2018_07_RVC_Hawkmoths\d023\r001\Camera No.1.cihx';
% nargin=1;

%% Function details
% checks that filename is a cih file
% opens .cih file
% finds fields and values in file (formatted as "field : value")
% make structure with fields and values

fieldnames={'Date';
            'DeviceName';
            'Time';
            'TriggerTime';
            'RecordRate_fps';
            'ShutterSpeed_s';
            'TotalFrame';
            'StartFrame';
            'CorrectTriggerFrame';
            'ImageWidth';
            'ImageHeight';
            'ColorType';
            'ColorBit';
            'FileFormat';
            'EffectiveBitDepth';
            'EffectiveBitSide';
            'DigitsOfFileNumber'};
        
fieldname_codes={'Date';
                 'DeviceName';
                 'Time';
                 'TriggerTime';
                 'recordRate';
                 'shutterSpeed';
                 'TotalFrame';
                 'StartFrame';
                 'CorrectTriggerFrame';
                 'Width';
                 'Height';
                 'Type';
                 'Bit';
                 'FileFormat';
                 'depth';
                 'side';
                 'DigitsOfFileNumber'};
        
%% Error checking
%if no arguments are input
if nargin==0
    [temp_fname,pname]=uigetfile(...
        '*.cih',... %file type
        'Select .cih file'); %text to user
    fname=fullfile(pname,temp_fname);
    clear pname temp_fname
end

% %confirm file is a .cih file
if strcmp(fname(end-3:end),'.cih')==false && strcmp(fname(end-4:end),'.cihx')==false
    error('file name must end in .cih or /.cihx')
end

%% Open .cih file
%open file and read text
meta_text_long=fileread(fname);

expression = '<(\w+).*>.*</\1>';
[fields,matches] = regexp(meta_text_long,expression,'tokens','match','dotexceptnewline');

for i=1:length(fields)
    
    fields2{i,1}=fields{i}{1};
    
end

entries = eraseTags(matches) ;
data=[fields2,entries'];

[folder, filename]=fileparts(fname);
cih_struct.filename=fullfile(folder, filename);

for i=1:length(fieldnames)
    
    a=contains(data(:,1),fieldname_codes{i},'IgnoreCase',1);
    
    if max(a)==1
        b=data{a==1,2};
        b=strtrim(b);

        if isnan(str2double(b))
            cih_struct.(fieldnames{i})=b;
        else
             cih_struct.(fieldnames{i})=str2double(b);
        end
    end
end