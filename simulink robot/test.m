clear;
clc;

addpath("../dependancies/dh");
addpath("../dependancies/rotations");
addpath("../dependancies/utils");
addpath("../dependancies/inv_kin");
addpath("../dependancies/dyn_model");
addpath("../dependancies/redundancy");
addpath("../modules/");
addpath("../robot_model/kuka-lwr-4plus");

function setGlobalRobot(val)
global robot;
robot = val;
end
function r = getGlobalRobot
global robot;
r = robot;
end

% Trajectory
% syms t R T C1 C2 C3 real
% radius = R; % 0.5;
% circle_center = [C1; C2; C3]; % [0; 0; 0.4];
% u_circle_plane = [1; 0; 0];  % must be unit vec and orth to v
% v_circle_plane = [0; 1; 0];  % must be unit vec and orth to u
% % T = 10;  % trajectory duration in seconds
% path(t) = circle_center + u_circle_plane*radius*cos((t/T) * (2*pi)) + v_circle_plane*radius*sin((t/T) * (2*pi));
% path_dot(t) = diff(path, t);
% path_ddot(t) = diff(path_dot, t);


% Intialize the KUKA robot
r = KukaLbr4pRobot();
setGlobalRobot(r);

% robot_to_try = "iiwa14";
robot_to_try = "lwr";

if robot_to_try == "iiwa14"
    robot_model = importrobot('iiwa14.urdf'); % Load KUKA iiwa14
else
    robot_model = importrobot("../robot_model/kuka-lwr-4plus/model1.urdf"); % Load KUKA LWR 4+
    % robot_model = importrobot("../robot_model/kuka-lwr-4plus/model1-withDyn1.urdf"); % Load KUKA LWR 4+
end
robot_model.DataFormat = 'column';
robot_model.Gravity = [0, 0, -9.80665];
setFixedTransform(robot_model.Bodies{8}.Joint, eye(4));

% smimport(robot_model);
% return;

% smimport(robot_model)
if robot_to_try == "iiwa14"
    open_system('robot_simulink.slx'); % iiwa14
else
    open_system('./kuka_test/lwr_scheme.slx'); % lwr4
end

% Load the Simulink file:
% sfile = "./simulink_proj/robot_model.slx";
% load_system(sfile);
% Run the simulation:
% sout = sim(sfile,'StopTime',int2str(T));