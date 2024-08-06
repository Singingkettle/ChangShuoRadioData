function [x,varargout]=minL1lin(C,d,varargin)
% The submission minL1lin finds the  minimum L1-norm solution of the linear equations C*x=d, 
% optionally under linear constraints. It is similar to the Optimization Toolbox's lsqlin except that it minimizes with 
% respect to the L1 norm by reformulating the problem as a linear program. The input/output syntax,
%  
%    [x,resnorm,residual,exitflag,output,lambda] = 
%           minL1lin(C,d,A,b,Aeq,beq,lb,ub,x0,options)
%  
%  is the same as for lsqlin() and all the usual defaults for A,b,..,x0 from
%  lsqlin apply here. However, the "options" are those of linprog() which is used 
%  internally. And, of course, the minimization is instead over norm(C*x-d,1)
%  rather than norm(C*x-d,2).
%
%
%
%EXAMPLES:
%
% We first construct some data for the examples
% 
% C=rand(3);
% 
% Xtrue=(1:3)'; 
%  noise=rand(3,1)*.1;
%  
% d=C*Xtrue+noise;
%  dTrue=C*Xtrue;
% 
%     %EXAMPLE 1:
%     %
%     %  This is an example of an unconstrained problem, in which we check the optimality
%     %  of the solution by simulation. First, we find the minimum L1 solution
%     %  of C*X-d
% 
%             [X,resnormX] = minL1lin(C,d,[],[],[],[],[],[],[],optimset('Display','none'));
% 
%     %  Now, we randomly generate many neighboring X and test the value of the objective
%     %  function in this neighborhood,
% 
%             Xneighbors=bsxfun(@plus,X,randn(3,1e6)*1e-6); %explore neighborhood of X
% 
%             resnormNeighbors=sum(abs(  bsxfun(@minus,  C*Xneighbors, d) )); %L1 error of neighbors
% 
%      % A value of 1 indicates all neighbors have a sub-optimal objective
%      
%             isOptimal=~any(resnormNeighbors<resnormX);
%             
%      % Typically it returns 1, indicating that all the neighbors are less
%      % optimal.
%      
%      isOptimal=~any(resnormNeighbors<resnormX)
% 
% 
%     %%EXAMPLE 2: 
%     %
%     %  In this continuation of EXAMPLE 1, we add linear constraints, and test the
%     %  improvement that this gives in the L1 error relative to the
%     %  noise-free true data, dTrue. For variety's sake, we now use the dual simplex
%     %  algorithm for this example,
% 
%                 Aeq=[1,1,1];
%                 beq=6;
%                 lb=[1;1;1];
%                 ub=[3;3;3];
% 
%                  options=optimoptions(@linprog,'Algorithm','dual-simplex','Display','none');
% 
% 
%             Xcon = minL1lin(C,d,[],[],Aeq,beq,lb,ub,[],options);
% 
%             error_Xunc = norm(C*X - dTrue,1),
%             error_Xcon = norm(C*Xcon - dTrue,1),
%             
%             
%       %Typically, one will observe error_Xcon < error_Xunc 
% 
% 

if length(varargin)<8
   varargin(end+1:8)={[]}; 
end

[A,b,Aeq,beq,lb,ub,x0,options]=deal(varargin{:});

[m,n]=size(C);

    
    f=[zeros(1,n), ones(1,m)];
    
   
    Ax=[C,-speye(m);-C,-speye(m)];
    bx=[d;-d];

  [~,nx]=size(Ax);   
 
    LB(1:nx)=-inf; 
       LB(n+1:end)=0;
    UB(1:nx)=inf;

    LB(1:length(lb))=lb;
    UB(1:length(ub))=ub;
    
    if ~isempty(A),
       A(end,nx)=0;
    end
    
    if ~isempty(Aeq),
       Aeq(end,nx)=0;
    end
    
    A=[A;Ax]; b=[b;bx];
    
   
    [xz,~, varargout{3:nargout-1}]=linprog(f,A,b,Aeq,beq,LB,UB,x0,options);

    
    if ~isempty(xz)
     x=xz(1:n);
    else
      x=xz;
      varargout(1:2)={[],[]}; 
      return
    end
    
    
    if nargout>=2 %truncate resnorm if requested
       residual=C*x-d;
       resnorm=norm(residual,1);
       varargout(1:2)={resnorm,residual}; 
    end
    
    
