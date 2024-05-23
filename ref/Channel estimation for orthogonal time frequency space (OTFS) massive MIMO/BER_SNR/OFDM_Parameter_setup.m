function [OFDM_Parameter] = OFDM_Parameter_setup(Index_Bandwith)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%function [BS_xy] = BS_Position(Index_Scenario)
%
% INPUT:   Index_Bandwith: Frequency band of the system        
% OUTPUTS: OFDM_Parameter: Parameter for OFDM transmission
%
% DESCRIPTION: Parameter of OFDM for transmission is generated based on TR25.814 for 3GPP LTE
%                    
% AUTHOR:  Jianjun Li /Hojin Kim     
% DATE: 07.26.2005
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Table_OFDM_Parameter = [1,2,4,8,12,16];


OFDM_Parameter=struct(  'Rate_Sampling',3.84/2*1e6*Table_OFDM_Parameter(Index_Bandwith),...                   
                        'Size_of_FFT',128*Table_OFDM_Parameter(Index_Bandwith),...                   
                        'Index_Fist_SC',28*Table_OFDM_Parameter(Index_Bandwith)+1,...                
                        'Number_subcarrier', 72*Table_OFDM_Parameter(Index_Bandwith)+1);