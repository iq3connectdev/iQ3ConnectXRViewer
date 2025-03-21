import ARKit
import SceneKit

class PlaneNode: SCNNode {
    @objc init(anchor: ARPlaneAnchor?) {
        super.init()

        setup()
        update(anchor)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    @objc func update(_ anchor: ARPlaneAnchor?) {
        guard let anchor = anchor else { return }
        let plane = geometry as? SCNPlane
        plane?.width = CGFloat(anchor.planeExtent.width)
        plane?.height = CGFloat(anchor.planeExtent.height)

        let material: SCNMaterial? = plane?.firstMaterial
        material?.diffuse.contentsTransform = SCNMatrix4MakeScale(anchor.planeExtent.width, anchor.planeExtent.height, 1)
        material?.diffuse.wrapS = .repeat
        material?.diffuse.wrapT = .repeat

        let translateTransform: SCNMatrix4 = SCNMatrix4MakeTranslation(anchor.center.x, 0, anchor.center.z)
        let rotationTransform: SCNMatrix4 = SCNMatrix4MakeRotation(-.pi / 2.0, 1.0, 0.0, 0.0)
        transform = SCNMatrix4Mult(rotationTransform, translateTransform)
    }

    func setup() {
        let plane = SCNPlane()

        let material = SCNMaterial()
        let img = UIImage(named: "Models.scnassets/plane_grid1.png")
        material.diffuse.contents = img
        material.diffuse.intensity = 0.5
        plane.materials = [material]

        geometry = plane
        transform = SCNMatrix4MakeRotation(-.pi / 2.0, 1, 0, 0)
        opacity = 0
    }
}
