clear;
clc;

% Import the robot
robot_model = importrobot("./robot_model/kuka-lwr-4plus/model1.urdf"); % Load KUKA LWR 4+
robot_model.DataFormat = 'column';
robot_model.Gravity = [0, 0, -9.80665];
setFixedTransform(robot_model.Bodies{8}.Joint, eye(4));

% Compute the direct kinematics
num_joints = 7;
a = sym('a', [1 num_joints]);
alpha = sym('alpha', [1 num_joints]);
d = sym('d', [1 num_joints]);
q = sym('q', [1 num_joints]);
a_cell = sym2cell(a);
alpha_cell = sym2cell(alpha);
d_cell = sym2cell(d);
q_cell = sym2cell(q);

A0e = eye(4);
for i=1:num_joints
    A0e = A0e * dh_mat_from_table( ...
        a(i), ...
        alpha(i), ...
        d(i), ...
        q(i) ...
    );
end
f = matlabFunction(A0e(1:3, 4));
nabla_a = matlabFunction(jacobian(A0e(1:3, 4), a));  % (alpha1-6, q1-7)
nabla_alpha = matlabFunction(jacobian(A0e(1:3, 4), alpha));  % (a2-7, alpha1-6, d2-7, q1-7)
nabla_d = matlabFunction(jacobian(A0e(1:3, 4), d));  % (alpha1-6, q1-6)

% syms q1 q2 q3 q4 q5 q6 q7 real % TODO:
% kuka_lbr_4p_dh_table = [ % a, alpha, d, theta  - retrieved from calibration with urdf model1
%     [0, pi/2,  0.31,  q(1)];
%     [0, -pi/2,  0,  q(2)];
%     [0, -pi/2,  0.4,  q(3)];
%     [0, pi/2,  0,  q(4)];
%     [0, pi/2,  0.39,  q(5)];
%     [0, -pi/2,  0,  q(6)];
%     [0, 0,  0,  q(7)];
% ];
% A0e_test = eye(4);
% for i=1:num_joints % TODO:
%     A0e_test = A0e_test * dh_mat_from_table( ...
%         kuka_lbr_4p_dh_table(i, 1), ...
%         kuka_lbr_4p_dh_table(i, 2), ...
%         kuka_lbr_4p_dh_table(i, 3), ...
%         kuka_lbr_4p_dh_table(i, 4) ...
%     );
% end
% A0e_test = matlabFunction(A0e_test(1:3, 4)); % TODO:


num_experiments = 15;
lMax = 20; % Num of iterations
m = 3; % The number of rows of the direct kinematics

% Intitialize the test configurations (randomly)
rng(0,'twister');
minLim = -2*pi;
maxLim = 2*pi;
q_m = (maxLim-minLim).*rand(num_experiments, num_joints) + minLim;

% Get the externally measured e.e. pos for the test configurations
p = zeros(num_experiments, m);  % e.e. pos corresponding to configurations in q_m
% p_test = zeros(num_experiments, m); % TODO:
for i=1:num_experiments
    tf = getTransform(robot_model, q_m(i, 1:num_joints)', robot_model.Bodies{8}.Name, robot_model.Bodies{1}.Name);
    p(i, 1:m) = tf(1:3, 4)';

    % inp = num2cell(q_m(i, 1:num_joints)); % TODO:
    % p_test(i, 1:m) = A0e_test(inp{1:4}); % TODO:
end
% err = p - p_test % TODO:
% return;

% Compute l iterations
% phi_n = [
%     a1 ... an, alpha1 ... alphan, d1 ... dn
% ]
phi_n = zeros(3 * num_joints, 1);
a_ind_start = 1;
alpha_ind_start = num_joints + a_ind_start;
d_ind_start = alpha_ind_start + num_joints;

% Set initial guesses
kuka_lbr_4p_dh_table = [ % a, alpha, d, theta
    0, sym(pi)/2,  0,         0
    0, -sym(pi)/2,  0,         0
    0, -sym(pi)/2,  0.4,         0
    0, sym(pi)/2,  0,         0
    0, sym(pi)/2,  0.39,         0
    0, -sym(pi)/2,  0,         0
    0, 0,  0,         0
];
phi_n(a_ind_start:num_joints, 1) = kuka_lbr_4p_dh_table(1:num_joints, 1)';
phi_n(alpha_ind_start:d_ind_start-1, 1) = kuka_lbr_4p_dh_table(1:num_joints, 2)';
phi_n(d_ind_start:end, 1) = kuka_lbr_4p_dh_table(1:num_joints, 3)';

phi_n_cell = num2cell(phi_n);
for l = 1:lMax
    tic
    % Compute delta_r_bar and phi_bar
    delta_r_bar = zeros(num_experiments*m, 1);
    phi_bar = zeros(num_experiments*m, 3*num_joints);
    for i = 1:num_experiments
        curr_f(q_cell{1:num_joints}) = f( ...
            phi_n_cell{a_ind_start:a_ind_start + num_joints - 1}, ...
            phi_n_cell{alpha_ind_start:alpha_ind_start-1+ num_joints-1}, ...  % INTROD -1
            phi_n_cell{d_ind_start:d_ind_start-1+num_joints}, ...
            q_cell{1:num_joints} ...
        );
    
        curr_cfg = q_m(i, 1:num_joints);
        curr_cfg = num2cell(curr_cfg);
        delta_r_bar((i-1)*m + 1:i*m, 1) = (p(i, 1:m)' - curr_f(curr_cfg{1:num_joints}))';
        phi_bar((i-1)*m + 1:i*m, 1:num_joints*3) = [
            nabla_a(phi_n_cell{alpha_ind_start:alpha_ind_start-1+ num_joints-1}, curr_cfg{1:num_joints}), ... % (alpha1-6, q1-7)
            nabla_alpha(phi_n_cell{a_ind_start + 1:a_ind_start + num_joints - 1}, phi_n_cell{alpha_ind_start:alpha_ind_start-1+ num_joints-1}, phi_n_cell{d_ind_start+1:d_ind_start-1+num_joints}, curr_cfg{1:num_joints}), ... % (a2-7, alpha1-6, d2-7, q1-7)
            nabla_d(phi_n_cell{alpha_ind_start:alpha_ind_start-1+ num_joints-1}, curr_cfg{1:num_joints-1}), ... % (alpha1-6, q1-6)
        ];
    end

    delta_phi = pinv(phi_bar) * delta_r_bar;
    phi_n = phi_n + delta_phi;
    phi_n_cell = num2cell(phi_n);

    iterDur = toc;
    fprintf('l=%d completed\tIterDur: %.2f\tETA: %.2f sec.\terr:%.6f\n', l, iterDur, (lMax-l)*iterDur, norm(delta_r_bar));
    % fprintf('l=%d completed\tIterDur: %.2f\tETA: %.2f sec.\n', l, iterDur, (lMax-l)*iterDur);

    if norm(delta_r_bar) < 1e-7 && phi_n(end-2) == 0 && phi_n(end) == 0 
        fprintf("Ended calibration prematurely because the error was < 1e-7");
        break;
    end
end
% disp(phi_n)

table(phi_n(1:num_joints), phi_n(num_joints+1:2*num_joints), phi_n(2*num_joints + 1:3*num_joints), 'VariableNames',{'a','alpha','d'})