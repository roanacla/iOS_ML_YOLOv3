//
//  CameraViewController.swift
//  iOS_ML_YOLOv3
//
//  Created by Roger Navarro on 11/1/20.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {

  //MARK: - IBOutlets
  @IBOutlet weak var liveCameraView: UIView!
  
  //MARK: - Properties
  let captureSession = AVCaptureSession()
  
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
    guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
      print("Error: no video devices available")
      return
    }
    
    //Verify if the user authorized camera use
    guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
      print("Error: could not create AVCaptureDeviceInput")
      return
    }
    
    if captureSession.canAddInput(videoInput) {
      captureSession.addInput(videoInput)
    }
    
    //Get camera view
    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
    previewLayer.connection?.videoOrientation = .portrait
    //Shoow camera view in liveCameraView
    liveCameraView.layer.addSublayer(previewLayer)
    previewLayer.frame = liveCameraView.bounds
    //Start capturing data
    captureSession.startRunning()
  }
  
}
