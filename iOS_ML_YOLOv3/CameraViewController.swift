//
//  CameraViewController.swift
//  iOS_ML_YOLOv3
//
//  Created by Roger Navarro on 11/1/20.
//

import UIKit
import AVFoundation
import Vision
import VideoToolbox
import CoreData

enum CameraSessionError: Error {
  case error
}
class CameraViewController: UIViewController {

  //MARK: - IBOutlets
  @IBOutlet weak var liveCameraView: UIView!
  @IBOutlet weak var image: UIImageView!
  
  
  //MARK: - Properties
  var context: NSManagedObjectContext?
  var captureSession: AVCaptureSession!
  let setupCameraQueue = DispatchQueue(label: "com.alquimia.setupCameraQueue")
  let videoOutput = AVCaptureVideoDataOutput()
  // Pixel Buffer Object
  var currentBuffer: CVPixelBuffer?
  // Load YOLOv3 model and configure settings
  lazy var visionModel: VNCoreMLModel? = {
    do {
      guard let modelURL = Bundle.main.url(forResource: "YOLOv3", withExtension: "mlmodelc") else {
        // return nil if model is missing
        return nil
      }
      let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))

      if #available(iOS 13.0, *) {
        visionModel.inputImageFeatureName = "image"
        visionModel.featureProvider = try MLDictionaryFeatureProvider(dictionary: [
          // set intersection over unit threshold
          "iouThreshold": MLFeatureValue(double: 0.45),
          // set confidence threshold
          "confidenceThreshold": MLFeatureValue(double: 0.25),
        ])
      }

      return visionModel
    } catch {
      fatalError("Failed to create VNCoreMLModel: \(error)")
    }
  }()
  // Set vision Analysis Request Object
  lazy var visionAnalysisRequest: VNCoreMLRequest? = {
    guard let visionModel = visionModel else { return nil }
    let request = VNCoreMLRequest(model: visionModel, completionHandler: {
      [weak self] request, error in
      self?.processObservations(for: request, error: error)
    })
    
    request.imageCropAndScaleOption = .scaleFill
    return request
  }()
  var boundingBoxViews = [BoundingBoxView]()
  public var frameInterval = 1
  var seenFrames = 0
  var predictions: [VNRecognizedObjectObservation] = []
  
  //MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    self.setUpBoundingBoxViews()
    self.startVideoCamera()
  }
  
  deinit {
    //Stop using camera after dismissing view
    captureSession.stopRunning()
  }
  
  //MARK: - IBActions
  @IBAction func snapObjects(_ sender: Any) {
    
    for prediction in predictions {
      let bestClass = prediction.labels[0].identifier
      let confidence = prediction.labels[0].confidence
      print(bestClass + " \(confidence)")
    }
    
    var cgImage: CGImage?
    VTCreateCGImageFromCVPixelBuffer(currentBuffer!, options: nil, imageOut: &cgImage)
    guard let imagecg = cgImage else {
      return
    }
    image.image = UIImage(cgImage: imagecg)
    
    guard let context = self.context else { return }
    let snap = Snap(context: context)
    snap.snapID = UUID()
    snap.photo = image.image?.pngData()
    for prediction in predictions {
      let objectInSnap = ObjectInSnap(context: context)
      objectInSnap.name = prediction.labels[0].identifier
      objectInSnap.confidence = Double(prediction.labels[0].confidence)
      snap.addToObjects(objectInSnap)
    }
    
    do {
      try context.save()
      dismiss(animated: true, completion: nil)
    } catch {
      fatalError("Core Data Save error")
    }
    
  }
  
  
  //MARK: - View Functions
  //0
  func setUpBoundingBoxViews() {
    for _ in 0..<10 {
      boundingBoxViews.append(BoundingBoxView())
    }
  }
  
  //1
  func startVideoCamera() {
    
    //Configure Camera before lunching
    self.setupCameraQueue.async {
      do {
        let cameraSessionSettings  = try self.getCameraSessionSettings()
        DispatchQueue.main.async {
          self.setUpCameraView(cameraSessionSettings: cameraSessionSettings)
        }
      } catch {
        print(error.localizedDescription)
      }
    }
  }
   
  // Returns AVCaptureSession if all camera configurations are done successfully
  //2
  func getCameraSessionSettings() throws -> AVCaptureSession {
    
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
  
  // Show in UIView camera input with settings
  //3
  func setUpCameraView(cameraSessionSettings session: AVCaptureSession) {
    
    self.captureSession = session
    // Get camera view
    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
    previewLayer.connection?.videoOrientation = .portrait
    //Shoow camera view in liveCameraView
    liveCameraView.layer.addSublayer(previewLayer)
    previewLayer.frame = liveCameraView.bounds
    
    for box in self.boundingBoxViews {
      box.addToLayer(self.liveCameraView.layer)
    }
    
    //Start capturing data
    captureSession.startRunning()
  }
  
  //5
  func predict(sampleBuffer: CMSampleBuffer) {
    if currentBuffer == nil, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
      currentBuffer = pixelBuffer

      // Get additional info from the camera.
      var options: [VNImageOption : Any] = [:]
      if let cameraIntrinsicMatrix = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
        options[.cameraIntrinsics] = cameraIntrinsicMatrix
      }

      let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: options)
      do {
        guard let visionAnalysisRequest = self.visionAnalysisRequest else { return }
        try handler.perform([visionAnalysisRequest])
      } catch {
        print("Failed to perform Vision request: \(error)")
      }
      currentBuffer = nil
    }
  }
  
  //6
  func processObservations(for request: VNRequest, error: Error?) {
    DispatchQueue.main.async {
      if let results = request.results as? [VNRecognizedObjectObservation] {
        self.show(predictions: results)
      } else {
        self.show(predictions: [])
      }
    }
  }
  
  //7
  func show(predictions: [VNRecognizedObjectObservation]) {
    self.predictions = predictions
    for i in 0..<boundingBoxViews.count {
      if i < predictions.count {
        let prediction = predictions[i]
        let width = view.bounds.width
        let height = width * 16 / 9
        let offsetY = (view.bounds.height - height) / 2
        let scale = CGAffineTransform.identity.scaledBy(x: width, y: height)
        let transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -height - offsetY)
        let rect = prediction.boundingBox.applying(scale).applying(transform)

        // The labels array is a list of VNClassificationObservation objects,
        // with the highest scoring class first in the list.
        let bestClass = prediction.labels[0].identifier
        let confidence = prediction.labels[0].confidence

        // Show the bounding box.
        let label = String(format: "%@ %.1f", bestClass, confidence * 100)
        let color = UIColor.gray
        boundingBoxViews[i].show(frame: rect, label: label, color: color)
      } else {
        boundingBoxViews[i].hide()
      }
    }
  }
  
}

// MARK: - Video Output Delegate
//4
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    self.seenFrames += 1
    if self.seenFrames >= self.frameInterval {
      self.seenFrames = 0
      self.predict(sampleBuffer: sampleBuffer)
    }
  }

  public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    //print("dropped frame")
  }
}
