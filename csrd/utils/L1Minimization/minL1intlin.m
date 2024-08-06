function [x,varargout]=minL1intlin(C,d,varargin)
% The submission minL1lin finds the  minimum L1-norm solution of the linear equations C*x=d, 
% optionally under linear constraints. It is similar to the Optimization Toolbox's lsqlin except that it minimizes with 
% respect to the L1 norm by reformulating the problem as a linear program. The input/output syntax,
%  
%    [x,resnormL1,residual,exitflag,output] = 
%           minL1intlin(C,d,intcon, A,b,Aeq,beq,lb,ub,x0,options)
%  
%  is the same as for lsqlin() and all the usual defaults for A,b,..,x0 from
%  lsqlin apply here. However, the "options" are those of intlinprog() which is used 
%  internally. And, of course, the minimization is instead over norm(C*x-d,1)
%  rather than norm(C*x-d,2).
%
%
%


if length(varargin)<9
   varargin(end+1:9)={[]}; 
end

[intcon, A,b,Aeq,beq,lb,ub,x0,~]=deal(varargin{:});
options = optimoptions('intlinprog','Display','off');
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
    
   
    [xz,~, varargout{3:nargout-1}]=intlinprog(f,intcon,A,b,Aeq,beq,LB,UB,x0,options);

    
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
    
    
