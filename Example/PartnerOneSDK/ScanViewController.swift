import UIKit
import AVFoundation
import FaceTecSDK

open class ScanViewController: BaseViewController<ScanView>, FaceTecFaceScanProcessorDelegate, URLSessionDelegate {
  
  /// FaceTec Variables
  var viewModel: ScanViewModel
  var viewTitle: String
  
  var previewLayer: AVCaptureVideoPreviewLayer!
  var captureSession: AVCaptureSession!
  var backCamera: AVCaptureDevice!
  var backInput: AVCaptureInput!
  var captureConnection: AVCaptureConnection?
  var photoOutput = AVCapturePhotoOutput()
  
  var latestSessionResult: FaceTecSessionResult!
  var latestIDScanResult: FaceTecIDScanResult!
  var latestProcessor: Processor!
  var utils: SampleAppUtilities?
  
  public init(viewModel: ScanViewModel, viewTitle: String = "") {
    self.viewModel = viewModel
    self.viewTitle = viewTitle
    super.init()
  }
  
  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    checkPermissions()
  }
  
  open override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    baseView.setupMaskLayer()
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    setupFaceTec()
    setupBinds()
  }
  
  open override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
  }
  
}

//MARK: - Setup AV Foundation Camera Presets

extension ScanViewController {
  func checkPermissions() {
    let cameraAuthStatus =  AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    switch cameraAuthStatus {
    case .authorized:
      self.startCaptureSession()
    case .denied: abort()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (authorized) in
        if(!authorized) {
          abort()
        }
      })
    case .restricted: abort()
    @unknown default: fatalError()
    }
  }
  
  func startCaptureSession() {
    DispatchQueue.global(qos: .userInitiated).async {
      self.captureSession = AVCaptureSession()
      self.captureSession.beginConfiguration()
      
      if self.captureSession.canSetSessionPreset(.photo) {
        self.captureSession.sessionPreset = .photo
      }
      
      if #available(iOS 10.0, *) {
        self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
      }
      
      self.setupInputs()
      
      DispatchQueue.main.async {
        self.setupPreviewLayer()
      }
      
      self.setupOutput()
      
      self.captureSession.commitConfiguration()
      self.captureSession.startRunning()
    }
  }
  
  func setupInputs() {
    if #available(iOS 10.0, *) {
      if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
        self.backCamera = device
      } else {
        fatalError("Sorry! There's no back camera available at this moment.")
      }
    }
    
    guard let bInput = try? AVCaptureDeviceInput(device: backCamera) else {
      fatalError("could not create input device from back camera")
    }
    backInput = bInput
    if !captureSession.canAddInput(backInput) {
      fatalError("could not add back camera input to capture session")
    }
    
    captureSession.addInput(backInput)
  }
  
  func setupOutput() {
    if captureSession.canAddOutput(photoOutput) {
      captureSession.addOutput(photoOutput)
    }
    
    photoOutput.connections.first?.videoOrientation = .portrait
  }
  
  func setupPreviewLayer(){
    let width = baseView.frame.width * 2
    let height = baseView.frame.height * 2
    
    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    baseView.cameraContainer.layer.insertSublayer(previewLayer,
                                                  below: baseView.background.cropReferenceView.layer)
    previewLayer.frame.size = CGSize(width: width, height: height)
    previewLayer.position = self.view.center
    
    
    baseView.cameraContainer.addSubview(baseView.background)
    baseView.sendSubview(toBack: baseView.cameraContainer)
  }
}

//MARK: - Picture Actions Delegate

@available(iOS 11.0, *)
extension ScanViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
  
  @objc
  func takePicure() {
    let photoSettings = AVCapturePhotoSettings()
    
    if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
      photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
      photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
  }
  
  public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    guard let imageData = photo.fileDataRepresentation() else { return }
    let previewImage = UIImage(data: imageData)
    
    let photoPreviewContainer = baseView.photoPreviewContainer
    photoPreviewContainer.imageView.image = previewImage
    
    viewModel.sendPicture()
    
    captureSession.stopRunning()
    baseView.photoPreviewContainer.isHidden = false
  }
}

extension ScanViewController {
  func setupBinds() {
    self.navigationItem.hidesBackButton = true
    baseView.viewTitle.text = viewTitle
    viewModel.sideTitle = viewTitle
    
    self.viewModel.didTapOpenFaceTec = {
      self.getSessionToken() { sessionToken in
        //        self.resetLatestResults()
        self.latestProcessor = LivenessCheckProcessor(sessionToken: sessionToken,
                                                      fromViewController: self)
      }
    }
    
    baseView.didTapTakePicture = { [weak self] in
      guard let self = self else { return }
      if #available(iOS 11.0, *) {
        self.takePicure()
      }
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        self.viewModel.navigateToNextView(self)
      }
    }
    
    baseView.didTapBack = { [weak self] in
      guard let self = self else { return }
      
      self.navigationController?.popViewController(animated: true)
      
      DispatchQueue.global(qos: .userInitiated).async {
        self.captureSession.startRunning()
      }
    }
  }
  func setupFaceTec() {
    FaceTec.initialize()
    FaceTec.sdk.initializeInDevelopmentMode(deviceKeyIdentifier: "",
                                            faceScanEncryptionKey: "")
    
    Config.initializeFaceTecSDKFromAutogeneratedConfig(completion: { initializationSuccessful in
        if(initializationSuccessful) {
            self.utils?.enableButtons(shouldEnable: true)
        } else {
            self.utils?.displayStatus(statusString: "\(FaceTec.sdk.description(for: FaceTec.sdk.getStatus()))")
        }
    })
    
    let currentTheme = Config.wasSDKConfiguredWithConfigWizard ? "Config Wizard Theme" : "FaceTec Theme"
    utils?.handleThemeSelection(theme: currentTheme)
  }
  
  public func processSessionWhileFaceTecSDKWaits(sessionResult: FaceTecSessionResult,
                                          faceScanResultCallback: FaceTecFaceScanResultCallback) {
  }
  
  public func onFaceTecSDKCompletelyDone() {
    print("COMPLETELY DONE")
  }
  
  func onComplete() {
    print("SCAN COMPLETED!")
  }
  
  func setLatestSessionResult(sessionResult: FaceTecSessionResult) {
      latestSessionResult = sessionResult
  }
  
  @objc
  func onLivenessCheckPressed(_ sender: Any) {
    getSessionToken() { sessionToken in
//        self.resetLatestResults()
      self.latestProcessor = LivenessCheckProcessor(sessionToken: sessionToken, fromViewController: self)
    }
    print("BUTTON TAPPED!")
  }
  
  func getSessionToken(sessionTokenCallback: @escaping (String) -> ()) {
      utils?.startSessionTokenConnectionTextTimer();

      let endpoint = Config.BaseURL + "/session-token"
      let request = NSMutableURLRequest(url: NSURL(string: endpoint)! as URL)
      request.httpMethod = "GET"
      // Required parameters to interact with the FaceTec Managed Testing API.
      request.addValue(Config.DeviceKeyIdentifier, forHTTPHeaderField: "X-Device-Key")
      request.addValue(FaceTec.sdk.createFaceTecAPIUserAgentString(""), forHTTPHeaderField: "User-Agent")

      let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
      let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
          // Ensure the data object is not nil otherwise callback with empty dictionary.
          guard let data = data else {
              print("Exception raised while attempting HTTPS call.")
              self.utils?.handleErrorGettingServerSessionToken()
              return
          }
          if let responseJSONObj = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: AnyObject] {
              if((responseJSONObj["sessionToken"] as? String) != nil) {
                  self.utils?.hideSessionTokenConnectionText()
                  sessionTokenCallback(responseJSONObj["sessionToken"] as! String)
                  return
              } else {
                  print("Exception raised while attempting HTTPS call.")
                  self.utils?.handleErrorGettingServerSessionToken()
              }
          }
      })
      task.resume()
  }
}

