//
//  ViewController.swift
//  ARML
//
//  Created by Joss Manger on 9/21/17.
//  Copyright © 2017 Joss Manger. All rights reserved.
//

import UIKit
import CoreML
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var cameraView: UIView!
    var captureSession: AVCaptureSession?
    var stillImageOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var backCamera:AVCaptureDevice?
    
    var currentImage:CIImage?
    
    @IBOutlet weak var previewImage: UIImageView!
    @IBOutlet weak var classLabel: UILabel!
    var timer:Timer?
    
    @IBOutlet weak var blueContainer: UIVisualEffectView!
    
    //photo
    let cameraOutput = AVCapturePhotoOutput()
    
    var classified = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        print("hello world")
        captureSession = AVCaptureSession()
        
        captureSession?.sessionPreset = AVCaptureSession.Preset.photo
        
        
//        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
//        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
//                             kCVPixelBufferWidthKey as String: 224,
//                             kCVPixelBufferHeightKey as String: 224]
//        settings.previewPhotoFormat = previewFormat
        
        guard let backCamera = AVCaptureDevice.default(for: .video) else {return}
        
        var error:NSError?
        do{
            
            let input = try AVCaptureDeviceInput(device: backCamera)
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:Int(kCVPixelFormatType_32BGRA)]
            output.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
            captureSession?.addOutput(output)
            captureSession!.addInput(input)
            
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            previewLayer!.frame = self.view.frame
            self.view.layer.insertSublayer(previewLayer!, below: blueContainer.layer)
            
            //photo capture
   
            captureSession?.addOutput(cameraOutput)
            
            
            
            //start view!
            captureSession?.startRunning()
            
            //timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(timerResponder), userInfo: nil, repeats: true)
            
        } catch let caughtError as NSError{
            error = caughtError
            print(error!)
            fatalError()
        }
        
        
        
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
                if let pixelbuffer = CMSampleBufferGetImageBuffer(sampleBuffer){
                    let ciimage = CIImage(cvPixelBuffer: pixelbuffer).oriented(.right)
                    DispatchQueue.main.sync {
                        
                        let image = UIImage(ciImage: ciimage)
                        self.previewImage.image = image
                        
                        if(self.classified==false){
                            self.updateClassifications(for: ciimage)
                            timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(timerResponder), userInfo: nil, repeats: false)
                            
                        }
                        
                    }
                    
                }
    }
    
    
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//        if let cgImage = photo.fileDataRepresentation(){
//            self.previewImage.image = UIImage(data: cgImage)
//        }
//
//    }

    @objc func timerResponder(){
        timer?.invalidate()
        print("timer")
        classified = false
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    override func viewDidLayoutSubviews() {
        previewLayer?.frame = self.cameraView.bounds ?? .zero
    }
 
    //MARK - Vision
    
    /// - Tag: PerformRequests
    func updateClassifications(for image: CIImage) {
        //classLabel.text = "Classifying..."
        
//        guard let image = image else {
//            return
//        }
        
        self.classified = true
        
        let orientation:CGImagePropertyOrientation = .down
   
        
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(ciImage: image, orientation: orientation)
            do {
                try handler.perform([self.classificationRequest])
            } catch {
                /*
                 This handler catches general image processing errors. The `classificationRequest`'s
                 completion handler `processClassifications(_:error:)` catches errors specific
                 to processing that request.
                 */
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            /*
             Use the Swift class `MobileNet` Core ML generates from the model.
             To use a different Core ML classifier model, add it to the project
             and replace `MobileNet` with that model's generated Swift class.
             */
            let model = try VNCoreMLModel(for: MobileNet().model)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    /// Updates the UI with the results of the classification.
    /// - Tag: ProcessClassifications
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.classLabel.text = "Unable to classify image."
                return
            }
            // The `results` will always be `VNClassificationObservation`s, as specified by the Core ML model in this project.
            let classifications = results as! [VNClassificationObservation]
            
            if classifications.isEmpty {
                self.classLabel.text = "Nothing recognized."
            } else {
                // Display top classifications ranked by confidence in the UI.
                let topClassifications = classifications.prefix(2)
                let descriptions = topClassifications.map { classification in
                    // Formats the classification for display; e.g. "(0.37) cliff, drop, drop-off".
                    return String(format: "  (%.2f) %@", classification.confidence, classification.identifier)
                }
  
                self.classLabel.text = "Classification:" + descriptions[0]
            }
        }
    }
    
    
    
}

