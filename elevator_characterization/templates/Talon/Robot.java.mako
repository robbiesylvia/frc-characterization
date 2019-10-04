/**
 * This is a very simple robot program that can be used to send telemetry to
 * the data_logger script to characterize your drivetrain. If you wish to use
 * your actual robot code, you only need to implement the simple logic in the
 * autonomousPeriodic function and change the NetworkTables update rate
 *
 * This program assumes that you are using TalonSRX motor controllers and that
 * the drivetrain encoders are attached to the TalonSRX
 */

package dc;

import java.util.function.Supplier;

import com.ctre.phoenix.motorcontrol.FeedbackDevice;
import com.ctre.phoenix.motorcontrol.NeutralMode;
import com.ctre.phoenix.motorcontrol.can.WPI_TalonSRX;

import edu.wpi.first.networktables.NetworkTableEntry;
import edu.wpi.first.networktables.NetworkTableInstance;
import edu.wpi.first.wpilibj.Joystick;
import edu.wpi.first.wpilibj.RobotController;
import edu.wpi.first.wpilibj.SpeedControllerGroup;
import edu.wpi.first.wpilibj.TimedRobot;
import edu.wpi.first.wpilibj.Timer;
import edu.wpi.first.wpilibj.drive.DifferentialDrive;
import edu.wpi.first.wpilibj.smartdashboard.SmartDashboard;

public class Robot extends TimedRobot {

  // The diameter of the pulley driving the elevator, in feet
  static private double PULLEY_DIAMETER = ${diam};
  static private double ENCODER_PULSE_PER_REV = ${ppr};
  static private int PIDIDX = 0;

  Joystick stick;

  ${controllers[0]} elevatorMaster;

  Supplier<Double> encoderPosition;
  Supplier<Double> encoderRate;

  NetworkTableEntry autoSpeedEntry =
      NetworkTableInstance.getDefault().getEntry("/robot/autospeed");
  NetworkTableEntry telemetryEntry =
      NetworkTableInstance.getDefault().getEntry("/robot/telemetry");

  double priorAutospeed = 0;
  Number[] numberArray = new Number[6];

  @Override
  public void robotInit() {

    stick = new Joystick(0);

    elevatorMaster = new ${controllers[0]}(${ports[0]});
    % if inverted[0]:
    elevatorMaster.setInverted(true);
    % else:
    elevatorMaster.setInverted(false);
    % endif
    % if encoderinv:
    elevatorMaster.setSensorPhase(true);
    % else:
    elevatorMaster.setSensorPhase(false);
    % endif
    elevatorMaster.setNeutralMode(NeutralMode.Brake);

    % for port in ports[1:]:
    ${controllers[loop.index+1]} elevatorSlave${loop.index} = new ${controllers[loop.index+1]}(${port});
    % if inverted[loop.index+1]:
    elevatorSlave${loop.index}.setInverted(true);
    % else:
    elevatorSlave${loop.index}.setInverted(false);
    % endif
    elevatorSlave${loop.index}.setNeutralMode(NeutralMode.Brake);
    elevatorSlave${loop.index}.follow(elevatorMaster);
    % endfor

    //
    // Configure encoder related functions -- getDistance and getrate should
    // return units and units/sec
    //

    double encoderConstant =
        (1 / ENCODER_PULSE_PER_REV) * PULLEY_DIAMETER * Math.PI;

    elevatorMaster.configSelectedFeedbackSensor(FeedbackDevice.QuadEncoder, PIDIDX,
                                          10);
    encoderPosition = ()
        -> elevatorMaster.getSelectedSensorPosition(PIDIDX) * encoderConstant +
               OFFSET;
    encoderRate =
        () -> elevatorMaster.getSelectedSensorVelocity(PIDIDX) * encoderConstant * 10;

    // Reset encoders
    elevatorMaster.setSelectedSensorPosition(0);

    // Set the update rate instead of using flush because of a ntcore bug
    // -> probably don't want to do this on a robot in competition
    NetworkTableInstance.getDefault().setUpdateRate(0.010);
  }

  @Override
  public void disabledInit() {
    System.out.println("Robot disabled");
    elevatorMaster.set(0);
  }

  @Override
  public void disabledPeriodic() {}

  @Override
  public void robotPeriodic() {
    // feedback for users, but not used by the control program
    SmartDashboard.putNumber("encoder_pos", encoderPosition.get());
    SmartDashboard.putNumber("encoder_rate", encoderRate.get());
  }

  @Override
  public void teleopInit() {
    System.out.println("Robot in operator control mode");
  }

  @Override
  public void teleopPeriodic() {
    elevatorMaster.set(-stick.getY());
  }

  @Override
  public void autonomousInit() {
    System.out.println("Robot in autonomous mode");
  }

  /**
   * If you wish to just use your own robot program to use with the data logging
   * program, you only need to copy/paste the logic below into your code and
   * ensure it gets called periodically in autonomous mode
   *
   * Additionally, you need to set NetworkTables update rate to 10ms using the
   * setUpdateRate call.
   */
  @Override
  public void autonomousPeriodic() {

    // Retrieve values to send back before telling the motors to do something
    double now = Timer.getFPGATimestamp();

    double position = encoderPosition.get();
    double rate = encoderRate.get();

    double battery = RobotController.getBatteryVoltage();

    double motorVolts = elevatorMaster.getMotorOutputVoltage();

    // Retrieve the commanded speed from NetworkTables
    double autospeed = autoSpeedEntry.getDouble(0);
    priorAutospeed = autospeed;

    // command motors to do things
    elevatorMaster.set(autospeed);

    // send telemetry data array back to NT
    numberArray[0] = now;
    numberArray[1] = battery;
    numberArray[2] = autospeed;
    numberArray[3] = motorVolts;
    numberArray[4] = position;
    numberArray[5] = rate;
    telemetryEntry.setNumberArray(numberArray);
  }
}
