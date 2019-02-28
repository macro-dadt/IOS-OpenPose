//
//  ViewController.swift
//  IOS-OpenPose
//
//  Created by Do Thanh Dat on 2019/02/28.
//  Copyright © 2019 DT Dat. All rights reserved.
//
import UIKit
import CoreML
import Vision
import Upsurge
@available(iOS 11.0, *)
class ViewController: UIViewController {
    
    //    let model = coco_pose_368()
    var babyImage:UIImage!
    let model = MobileOpenPose()
    let ImageWidth = 368
    let ImageHeight = 368
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0
    var magrin: CGFloat = 0.0
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var imageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.setNeedsDisplay()
        self.view.layoutIfNeeded()
        
        imageView.contentMode = .scaleAspectFit
        imageView.image  = UIImage(named: "human-pose.jpg")
        let w = imageView.frame.width
        let h = w * ((imageView.image?.size.height)!/(imageView.image?.size.width)!)
        scaleX = w/368
        scaleY = h/368
        magrin = (imageView.frame.height - h)/2
        runCoreML(imageView.image!)
    }
    override func viewDidLayoutSubviews() {
   

     
    }
    func measure <T> (_ f: @autoclosure () -> T) -> (result: T, duration: String) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = f()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, "Elapsed time is \(timeElapsed) seconds.")
    }
    lazy var classificationRequest: [VNRequest] = {
        do {
            let model = try VNCoreMLModel(for: self.model.model)
            let classificationRequest = VNCoreMLRequest(model: model, completionHandler: self.handleClassification)
            return [ classificationRequest ]
        } catch {
            fatalError("Can't load Vision ML model: \(error)")
        }
    }()
    
    func handleClassification(request: VNRequest, error: Error?) {
        
        guard let observations = request.results as? [VNCoreMLFeatureValueObservation] else { fatalError() }
        let mlarray = observations[0].featureValue.multiArrayValue!
        let length = mlarray.count
        let doublePtr =  mlarray.dataPointer.bindMemory(to: Double.self, capacity: length)
        let doubleBuffer = UnsafeBufferPointer(start: doublePtr, count: length)
        let mm = Array(doubleBuffer)
        
        drawLine(mm)
    }
    
    func runCoreML(_ image: UIImage) {
        //imageView.image = image
        
        let img = image.resize(to: CGSize(width: ImageWidth,height: ImageHeight)).cgImage!
        let classifierRequestHandler = VNImageRequestHandler(cgImage: img, options: [:])
        do {
            try classifierRequestHandler.perform(self.classificationRequest)
        } catch {
            print(error)
        }
    }
    
    func drawLine(_ mm: Array<Double>){
        
        let com = PoseEstimator(ImageWidth,ImageHeight)
        
        let res = measure(com.estimate(mm))
        let humans = res.result;
        print("estimate \(res.duration)")
        
        var keypoint = [Int32]()
        var pos = [CGPoint]()
        for human in humans {
            var centers = [Int: CGPoint]()
            for i in 0...CocoPart.Background.rawValue {
                if human.bodyParts.keys.index(of: i) == nil {
                    continue
                }
                
                let bodyPart = human.bodyParts[i]!
                if bodyPart.partIdx > 13 || bodyPart.partIdx < 8 {
                    //continue
                }
                print("bodyPart: ",bodyPart.x, bodyPart.y)
                centers[i] = CGPoint(x: bodyPart.x, y: bodyPart.y)
                centers[i] = CGPoint(x: Int(bodyPart.x * CGFloat(ImageWidth) * scaleX  + 0.5), y: (Int(bodyPart.y * CGFloat(ImageHeight) * scaleY +  magrin + 0.5)))
                
            }
            
            for (pairOrder, (pair1,pair2)) in CocoPairsRender.enumerated() {
                
                if human.bodyParts.keys.index(of: pair1) == nil || human.bodyParts.keys.index(of: pair2) == nil {
                    continue
                }
                if centers.index(forKey: pair1) != nil && centers.index(forKey: pair2) != nil{
                    keypoint.append(Int32(pairOrder))
                    pos.append(centers[pair1]!)
                    pos.append(centers[pair2]!)
                    addLine(fromPoint: centers[pair1]!, toPoint: centers[pair2]!, color: CocoColors[pairOrder])
                }
            }
        }
    }
    
    func addLine(fromPoint start: CGPoint, toPoint end:CGPoint, color: UIColor) {
        let line = CAShapeLayer()
        let linePath = UIBezierPath()
        
        linePath.move(to: start)
        linePath.addLine(to: end)
        line.path = linePath.cgPath
        line.strokeColor = color.cgColor
        line.lineWidth = 3
        line.lineJoin = CAShapeLayerLineJoin.round
        self.view.layer.addSublayer(line)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension UIImage {
    func resize(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
}



