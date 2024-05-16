function [BWStruct, codeStruct] = OFDMGetTables(BWIndex,codeRateIndex)
%OFDMGetTables Return common tx/rx parameters.
%   This helper is called from the tx and rx functions to return a common
%   set of system parameters from index pointer. Index a desired bandwidth
%   index to return the FFT length, CP length, subcarrier spacing (symbol
%   rate), and number of data subcarriers per OFDM symbol.
%
%   [BWStruct, codeStruct] = helperOFDMGetTables(BWIndex,codeRateIndex)
%   BWIndex - index into BW table
%   codeRateIndex - index into code rate table
%   BWStruct = {FFT length, CP length, number of occupied subcarriers,
%   subcarrier spacing, pilot subcarrier spacing, channel BW}:
%
%   * 1 = {128,  32,   72,  15e3,   9,   1.4e6} (default)
%   * 2 = {256,  64,  180,  15e3,   20,  3e6}
%   * 3 = {512,  128, 300,  15e3,   20,  5e6}
%   * 4 = {1024, 256, 600,  15e3,   20,  10e6}
%   * 5 = {2048, 512, 1200, 15e3,   24,  20e6}
%   * 6 = {128,  32,  112,  312.5e3, 14, 35.6e6}
%   * 7 = {4096, 1024, 3276, 30e3,  36,  98.28e6}
%
%   codeStruct = structure comprising code rate, puncture vector,
%   constraint length, and traceback depth of the convolutional coder.

% Copyright 20224 The Citybuster, Edu.

BWTable = [ ...
    128,    32,     72,     15e3,   9,  1.4e6; ...
    256,    64,     180,    15e3,   20,  3e6; ...
    512,    128,    300,    15e3,   20,  5e6; ...
    1024,   256,    600,    15e3,   20,  10e6; ...
    2048,   512,    1200,   15e3,   24,  20e6; ...
    128,    32,     112,    312.5e3, 14, 35.6e6; ...
    4096,   1024,   3276,   30e3,   36,  98.28e6];

% Error check
if isempty(BWIndex)
    BWIndex = 1;
end
if BWIndex < 1 || BWIndex > size(BWTable,1)
    BWIndex = 1;
end

BWStruct = struct( ...
    'FFTLen',       BWTable(BWIndex,1), ...
    'CPLen',        BWTable(BWIndex,2), ...
    'numSubCarr',   BWTable(BWIndex,3), ...
    'scs',          BWTable(BWIndex,4), ...
    'pilotSpacing', BWTable(BWIndex,5), ...
    'BW',           BWTable(BWIndex,6));

% Select puncture vector and punctured code rate. The traceback depth of
% the Viterbi decoder roughly follows a rule of thumb of 2x-3x the factor
% (constraint length - 1) / (1 - codeRate)
codeStruct = struct( ...
     'puncVec',[], ...
     'codeRate',[], ...
     'codeRateK',[], ...
     'tracebackDepth',[]);
switch codeRateIndex
    case 1
        codeStruct.puncVec = [1 1 0 1];
        codeStruct.codeRate = 2/3;
        codeStruct.codeRateK = 3;
        codeStruct.tracebackDepth = 45;
    case 2
        codeStruct.puncVec = [1 1 1 0 0 1];
        codeStruct.codeRate = 3/4;
        codeStruct.codeRateK = 4;
        codeStruct.tracebackDepth = 60;
    case 3
        codeStruct.puncVec = [1 1 1 0 0 1 1 0 0 1];
        codeStruct.codeRate = 5/6;
        codeStruct.codeRateK = 6;
        codeStruct.tracebackDepth = 90;
    otherwise
        % Default to index 0
        codeStruct.puncVec = [1 1];
        codeStruct.codeRate = 1/2;
        codeStruct.codeRateK = 2;
        codeStruct.tracebackDepth = 30;
end

end