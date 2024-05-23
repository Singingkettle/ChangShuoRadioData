function [h_i, Omega] = OMP(y,P,S)      
 N=size(y,1);
 K= size(P,2);

 err= 1e-3;  
h_i = zeros(K, 1);  % Initialize the recovery signal
y_i = y - P * h_i;    % residual error

it=0;
stop = 0;
P_s = [];
pos_array=[];
while ~stop                     
           for ntl=1:1:K
                product(ntl)=abs(P(:,ntl)'*y_i);      %  Step 1): calculate the correlation between the (1+(l-1)*Nt)-th  to (l*Nt)-th  columns and the residual signal 
           end
            
             y_i_before=y_i;    
            [val,pos]=max(product);                       %  Step 2): find the value and position of the most matching columns
           
            P_s=[P_s,P(:,pos)];  pos_array= [pos_array,pos];  %  Step 3): update the argment matrix and record the position,
            P(:,pos)=zeros(N,1);                        %           remove the column just selected
            h_s=(P_s'*P_s)^(-1)*P_s'*y; 
%             h_s = P_s\y;                       %  Step 4): solve the LS problem to obatain a new signal estimate
            y_i = y - P_s*h_s;                          %  Step 5): Calculate the new residual
                                              
           it = it + 1;                                  %Iteration counter              
                                                     
    %Check Halting Condition
    if (it >= S  )  ||  norm(y_i) <=err*norm(y) 
      stop = 1;
    end
%     ||  norm(y_i) <=err*norm(y) 
%     ||norm( y_i) >= norm( y_i_before)
end
  h_i(pos_array) = (P_s'*P_s)^(-1)*P_s'*y;    %  Step 7): get the recovered signal
 %End CoSaMP iteration
%  used_iter = it;
  Omega=pos_array;                    