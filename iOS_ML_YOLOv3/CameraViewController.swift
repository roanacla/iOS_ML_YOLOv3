//
//  CameraViewController.swift
//  iOS_ML_YOLOv3
//
//  Created by Roger Navarro on 11/1/20.
//

import UIKit
import AVFoundation

enum CameraSessionError: Error {
  case error
}
class CameraViewController: UIViewController {

  //MARK: - IBOutlets
  @IBOutlet weak var liveCameraView: UIView!
  
  //MARK: - Properties
//  let captureSession = AVCaptureSession()
  var captureSession: AVCaptureSession!
  let setupCameraQueue = DispatchQueue(label: "com.alquimia.setupCameraQueue")
  let videoOutput = AVCaptureVideoDataOutput()
  
  //MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    self.startVideoCamera()
  }
  
  deinit {
    //Stop using camera after dismissing view
    captureSession.stopRunning()
  }
  
  //MARK: - View Functions
  func startVideoCamera() {
    
    //Configure Camera before lunching
    self.setupCameraQueue.async {
      do {
        let cameraSessionSettings  = try self.setupCameraSessionSettings()
        DispatchQueue.main.async {
          self.setUpCameraView(cameraSessionSettings: cameraSessionSettings)
        }
      } catch {
        print(error.localizedDescription)
      }
    }
  }
   
  // Show in UIView camera input with settings
  func setUpCameraView(cameraSessionSettings session: AVCaptureSession) {
    
    self.captureSession = session
    // Get camera view
    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
    previewLayer.connection?.videoOrientation = .portrait
    //Shoow camera view in liveCameraView
    liveCameraView.layer.addSublayer(previewLayer)
    previewLayer.frame = liveCameraView.bounds
    //Start capturing data
    captureSession.startRunning()
  }
  
  // Returns AVCaptureSession if all camera configurations are done successfully
  func setupCameraSessionSettings() throws -> AVCaptureSession {
    
    //Verify if the user has a working camera
    guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
      print("Error: no video devices available")
      throw CameraSessionError.error
    }
    
    // Verify if the user authorized camera use
    guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
      print("Error: could not create AVCaptureDeviceInput")
      throw CameraSessionError.error
    }
    
    //Define capture session
    let captureSession = AVCaptureSession()
    
    // Indicate the start of a batch of configurations to the camera
    captureSession.beginConfiguration()
    
    // Define the input camera resulution
    captureSession.sessionPreset = .hd1280x720
//    captureSession.sessionPreset = .vga640x480
    
    // Difine how the camera is going to be used. In this case video
    if captureSession.canAddInput(videoInput) {
      captureSession.addInput(videoInput)
    }
    
    let settings: [String : Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
    ]
   
    // Define video settings
    self.videoOutput.videoSettings = settings
    self.videoOutput.alwaysDiscardsLateVideoFrames = true
    
    // Define who is going to take kare of custom process made to the video
    self.videoOutput.setSampleBufferDelegate(self, queue: self.setupCameraQueue)
    
    if captureSession.canAddOutput(videoOutput) {
      captureSession.addOutput(videoOutput)
    }
    
    //Set video orientation
    self.videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
    
    //Indicate the end of a batch of configurations to the camera
    captureSession.commitConfiguration()
    
    return captureSession
  }
  
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  
}
