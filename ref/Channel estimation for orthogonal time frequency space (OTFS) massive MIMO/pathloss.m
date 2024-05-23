function loss=pathloss(scmpar,linkpar)
%PATHLOSS Pathloss models for 2GHz and 5GHz 
%   PATH_LOSSES=PATHLOSS(SCMPAR,LINKPAR) returns path losses in dB scale
%   for all links defined in SCM input struct LINKPAR for the center 
%   frequency and scenario given in SCMPAR. The output is a column vector
%   whose length is equal to the number of links defined in LINKPAR, e.g. 
%   LENGTH(LINKPAR.MsBsDistance). The center frequencies and distances  in
%   SCMPAR must be specified in Herzes and meters, respectively. 
%   
%   PATHLOSS supports 2 GHz center frequency and the SCM scenarios:
%   suburban macro, urban macro, and urban micro [1].  MS and BS heights
%   are not currently supported. 
%
%   The 2GHz path loss model is based on [1, Table 5.1]. 
%
%   Refs.   [1]: 3GPP TR 25.996 v6.1.0 (2003-09)
%
%   See also SCMPARSET and LINKPARSET.

%   Authors: Jari Salo (HUT), Daniela Laselva (EBIT)
%   $Revision: 0.21 $  $Date: Dec 12, 2004$



% extract required parameters from the input structs
NumUsers=length(linkpar.MsBsDistance);
MsBsDistance=linkpar.MsBsDistance;
Scenario=scmpar.Scenario;
CenterFrequency=scmpar.CenterFrequency;
Options=scmpar.ScmOptions;

% print out a warning if center freqency is not within a tolerance
tol=2e8;    % Hz
if (abs(CenterFrequency - 2e9)>tol) 
    CenterFrequency=2e9;
    warning('MATLAB:CenterFrequencyChanged','Center frequency of 2GHz used for path loss computation.')
else
    CenterFrequency=2e9;
end


switch lower(Scenario)
    
    case {'suburban_macro'}
        
        switch (CenterFrequency)            % other frequencies may be added, if necessary
            
            case (2e9)                      % SCM suburban macro [1, Section 5.2 and Table 5.1]
                if (min(MsBsDistance)<35)   
                    warning('MATLAB:TooSmallMsBsDistance','MsBsDistance less than 35 meters encountered. Path loss computation may be unreliable.')
                end
                loss=31.5+35*log10(MsBsDistance);
        end
        
        
    case {'urban_macro'}
        
        switch (CenterFrequency)            % other frequencies may be added, if necessary
            
            case (2e9)                      % SCM urban_macro model [1, Section 5.2 and Table 5.1]
                if (min(MsBsDistance)<35)
                    warning('MATLAB:TooSmallMsBsDistance','MsBsDistance less than 35 meters encountered. Path loss computation may be unreliable.')
                end
                loss=34.5+35*log10(MsBsDistance);    
                
        end
        
        
    case {'urban_micro'}        
        
        % options for urban micro
        switch lower(Options)
            
            case {'none','polarized','urban_canyon'}
                
                switch (CenterFrequency)    % other frequencies may be added, if necessary
                    
                    case (2e9)              % SCM urban micro model [1, Section 5.2 and Table 5.1]
                        if (min(MsBsDistance)<20)
                            warning('MATLAB:TooSmallMsBsDistance','MsBsDistance less than 20 meters encountered. Path loss computation may be unreliable.')
                        end
                        loss=34.53+38*log10(MsBsDistance);
                        
                end
    
                
            case ('los')
                
                switch (CenterFrequency)    % other frequencies may be added, if necessary
                    
                    case (2e9)              % SCM urban micro model [1, Section 5.2 and Table 5.1]
                        if (min(MsBsDistance)<20)
                            warning('MATLAB:TooSmallMsBsDistance','MsBsDistance less than 20 meters encountered. Path loss computation may be unreliable.')
                        end
                        loss=30.18+26*log10(MsBsDistance);
                        
                end
                
                
        end % end options for urban micro
        
        
        
end     % end switch Scenario


% output
loss=loss(:);       
