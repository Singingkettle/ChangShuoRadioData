classdef PM < FM

    methods

        function modulator = getModulator(obj)

            modulator = @(x)basePMModulator(x, ...
                obj.modulatorConfig.phaseDev, ...
                obj.modulatorConfig.initPhase);

        end
        
    end

end


function y = basePMModulator(x, ini_phase)


 y = complex(cos(phasedev*x + ini_phase), sin(phasedev*x + ini_phase))/2;  

end