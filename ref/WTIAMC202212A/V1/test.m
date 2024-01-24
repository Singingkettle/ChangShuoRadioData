a = zeros(1, 5);
for i=1:100000
    id = uint8(randi(5));
a(1, id) = a(1, id) + 1;
end

a./100000