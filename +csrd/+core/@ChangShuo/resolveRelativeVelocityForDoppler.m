function [relativeVelocityMps, txVelocityMps, rxVelocityMps] = ...
        resolveRelativeVelocityForDoppler(txInfo, rxInfo)
    %RESOLVERELATIVEVELOCITYFORDOPPLER Resolve Tx/Rx relative velocity.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 resolveRelativeVelocityForDoppler 实现。
    %
    %   Doppler is driven by relative motion along the Tx-to-Rx line of
    %   sight. applyDopplerShift assumes its velocity input has already
    %   been composed for a stationary receiver, so the channel propagation
    %   path must pass TxVelocity - RxVelocity here.

    txVelocityMps = localVelocityOrZero(txInfo, 'txInfo.Velocity');
    rxVelocityMps = localVelocityOrZero(rxInfo, 'rxInfo.Velocity');
    relativeVelocityMps = txVelocityMps - rxVelocityMps;
end


function velocity = localVelocityOrZero(info, context)
    % localVelocityOrZero - Production declaration in CSRD.
    % 中文说明：localVelocityOrZero 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if ~isstruct(info) || ~isfield(info, 'Velocity') || isempty(info.Velocity)
        velocity = [0, 0, 0];
        return;
    end

    velocity = info.Velocity;
    if ~isnumeric(velocity) || numel(velocity) ~= 3 || ...
            any(~isfinite(velocity(:)))
        error('CSRD:Channel:DopplerInvalidGeometryVector', ...
            'resolveRelativeVelocityForDoppler: %s must be a finite 3-element velocity vector.', ...
            context);
    end
    velocity = double(velocity(:)).';
end
