function [X, train_error, test_error, run_time, norm_value] = gnmds_x_epoch_time(init_X, train_triplets, test_triplets, no_dims, eta, no_repeat, batch_iter, svrg_iter, lambda)
%GNMDS_X_EPOCH Generalized Non-metric Multi-Dimensional Scaling w.r.t. X
%
%   [X, train_error, test_error] = gnmds_x_epoch(init_X, train_triplets, test_triplets, no_dims, no_repeat, batch_iter, svrg_iter, lambda)
%
% The function implements generalized non-metric MDS (GNMDS) based on the 
% specified triplets, to construct an embedding X with no_dims dimensions. 
% The parameter lambda specifies the amount of L2- regularization (default 
% = 0).
%
% Note: This function directly learns the embedding X and returns the train & test error for each epoch.
% It is modifed with the code provided by Laurens van der Maaten, 2012, Delft University of Technology

if ~exist('no_dims', 'var') || isempty(no_dims)
	no_dims = 2;
end
if ~exist('lambda', 'var') || isempty(lambda)
	lambda = 0;
end
addpath(genpath('minFunc'));

% Determine number of objects
N = max(train_triplets(:));
train_triplets(any(train_triplets == -1, 2),:) = [];
no_train = size(train_triplets, 1);
no_test = size(test_triplets, 1);

% Initialize some variables
% X = randn(N, no_dims) .* .0001;
% convergence tolerance 
tol = 1e-5;
% maximum number of iterations
% max_iter = 1000;
% learning rate
% eta = 0.5;
% best error obtained so far
% best_C = Inf;
% best embedding found so far
% best_X = X;
C = Inf;
X = init_X;
train_error = zeros(1, svrg_iter);
test_error = zeros(1, svrg_iter);
run_time = zeros(1, svrg_iter);
norm_value = zeros(1, svrg_iter);

% Perform main learning iterations
iter = 0;
no_incr = 0;
t = 1;
% while iter < max_iter && (no_incr < 5 || iter < 50)
while iter < batch_iter
	tt = clock;
	% Compute value of slack variables, cost function, and gradient
	old_C = C;
	[C, G, slack] = gnmds_x_grad(X(:), N, no_dims, train_triplets, 'hinge', lambda);
	
	% Maintain best solution found so far
	% if C < best_C
	%	best_C = C;
	%	best_X = X;
	% end
	
	% Perform gradient update        
	% X = X - (eta ./ no_train .* N) .* reshape(G, [N no_dims]);
	X = X - (eta ./ no_train * N) .* reshape(G, [N no_dims]);
	% Update learning rate
	if old_C > C + tol
		no_incr = 0;
		eta = eta * 1.01;
	else
		no_incr = no_incr + 1;
		eta = eta * .5;
	end
	run_time(t) = run_time(t) + etime(clock, tt);

	% Print out progress
	iter = iter + 1;
	if ~rem(iter, no_repeat+2)
		no_slack = sum(slack > 1);
		% disp(['Iteration ' num2str(iter) ': error is ' num2str(C) ...', 
		%	number of constraints: ' num2str(no_slack ./ no_triplets)]);
		sum_X = sum(X .^ 2, 2);
		D = bsxfun(@plus, sum_X, bsxfun(@plus, sum_X', -2 * (X * X')));
		% no_train_viol = sum(D(sub2ind([N N], train_triplets(:,1), train_triplets(:,2))) > ...
		%				D(sub2ind([N N], train_triplets(:,1), train_triplets(:,3))));
		no_test_viol = sum(D(sub2ind([N N], test_triplets(:,1), test_triplets(:,2))) > ...
						D(sub2ind([N N], test_triplets(:,1), test_triplets(:,3))));
		train_error(t) = no_slack ./ no_train;
		test_error(t) = no_test_viol ./ no_test;
		norm_value(t) = norm(X, 'fro');
		%if test_error(t) <= 0.2
		%	run_time = etime(clock, tt);
		%	break;
		%end
		t = t+1;
	end
end
