classdef TorqueControllers
% TorqueControllers The class that defines all the controllers used for Cartesian control in this project
    
    properties(Constant)
        K_p = 10;
        K_d = 10;
        K_v = 10;
    end

    methods(Static)
        function u = fullLinearizationInNullSpace(robot, curr_joint_pos, curr_joint_vel, curr_cart_pos)
            % Returns a control law that performs linearization and decoupling of the robot in the
            %  Cartesian Space, while following the provided trajectory.
            % robot: The KukaLbrRobot instance that represents the robot that this control law is applied to.
            % curr_joint_pos: The position of all the joints at the current instant (q_i).
            % curr_joint_vel: The velocity of all the joints at the current instant (q_dot_i).
            % curr_cart_pos: The position to reach in the Cartesian space at the current instant (p_des(t)).
            
            % Compute the dynamic terms in the current configuration
            [~, M_q, c_q_qdot, g_q] = robot.get_numerical_dyn_terms();
            M_q = subs(M_q, robot.joints_pos, curr_joint_pos);
            c_q_qdot = subs(c_q_qdot, robot.joints_pos, curr_joint_pos);
            c_q_qdot = subs(c_q_qdot, robot.joints_vel, curr_joint_vel);
            g_q = subs(g_q, robot.joints_pos, curr_joint_pos);

            % Compute the numeric value of the Jacobian in the current configuration (J(q))
            [~, J_q] = robot.get_jacobian(curr_joint_pos);
            J_q = double(J_q);
            J_q_pinv = pinv(J_q);
            [~, J_dot_q] = robot.get_j_dot(curr_joint_pos, curr_joint_vel);
            J_dot_q = double(J_dot_q);

            % Compute the direct kinematics with the actual data
            [~, A0e] = robot.compute_direct_kinematics(curr_joint_pos);
            curr_ee_pos = A0e(1:3, 4);
            a = J_q_pinv * (TorqueControllers.K_p * (curr_cart_pos - curr_ee_pos) - J_dot_q * curr_joint_vel) - ...
                (eye(robot.num_joints) - J_q_pinv * J_q) * (TorqueControllers.K_v * curr_joint_vel);
            u = M_q*a + c_q_qdot + g_q;
        end
    end
end