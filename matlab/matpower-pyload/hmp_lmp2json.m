function str_to_send = hmp_lmp2json(prices_at_all_nodes, load_node_map)
%HMP_LMP2JSON serialize lmp values as a dictionary string

prices_to_send = prices_at_all_nodes(cell2mat(load_node_map(:,2)));
cell_to_send = [load_node_map(:,1), num2cell(prices_to_send)]';
str_to_send = jsonencode(struct(cell_to_send{:}));