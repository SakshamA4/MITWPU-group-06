import UIKit

class CompassView: UIView {

    private let backgroundView = UIView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let dialView = UIView()
    private let ticksContainer = UIView()
    private let northLabel = UILabel()
    private let southLabel = UILabel()
    private let eastLabel = UILabel()
    private let westLabel = UILabel()
    private let needleView = UIView()
    private let needleTip = UIView()
    private let centerDot = UIView()

    var onNorthTap: (() -> Void)?
    var onPan: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = bounds.width / 2
        backgroundView.layer.cornerRadius = radius
        blurView.layer.cornerRadius = radius
        layer.cornerRadius = radius

        // Ensure perfect circular clipping
        clipsToBounds = true
    }

    private func setupUI() {
        backgroundColor = .clear

        // Background Base (Solid black with some alpha for glass effect)
        backgroundView.backgroundColor = UIColor(white: 0.05, alpha: 0.95)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)

        // Glass effect
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)

        // Border / Rim
        backgroundView.layer.borderWidth = 1.5
        backgroundView.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor

        // Ticks Container (doesn't rotate)
        ticksContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ticksContainer)
        setupTicks()

        // Rotating Dial
        dialView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dialView)

        setupLabels()
        setupNeedle()

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            ticksContainer.topAnchor.constraint(equalTo: topAnchor),
            ticksContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            ticksContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            ticksContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            dialView.centerXAnchor.constraint(equalTo: centerXAnchor),
            dialView.centerYAnchor.constraint(equalTo: centerYAnchor),
            dialView.widthAnchor.constraint(equalTo: widthAnchor),
            dialView.heightAnchor.constraint(equalTo: heightAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(pan)

        // Add a subtle inner shadow/glow
        let innerShadow = CALayer()
        innerShadow.frame = bounds
        innerShadow.cornerRadius = bounds.width / 2
        innerShadow.shadowColor = UIColor.white.cgColor
        innerShadow.shadowOffset = .zero
        innerShadow.shadowRadius = 10
        innerShadow.shadowOpacity = 0.05
        layer.addSublayer(innerShadow)
    }

    private func setupTicks() {
        // Create degree markers
        for i in 0..<72 { // Every 5 degrees
            let tick = UIView()
            let isMajor = i % 18 == 0 // N, E, S, W
            let isSecondary = i % 2 == 0 // Every 10 degrees

            tick.backgroundColor = isMajor ? .systemRed : (isSecondary ? UIColor.white.withAlphaComponent(0.4) : UIColor.white.withAlphaComponent(0.15))

            let width: CGFloat = isMajor ? 2 : (isSecondary ? 1 : 0.5)
            let height: CGFloat = isMajor ? 8 : (isSecondary ? 5 : 3)

            tick.frame = CGRect(x: 0, y: 0, width: width, height: height)
            tick.layer.cornerRadius = width / 2

            // Position the tick
            let angle = CGFloat(i) * 5.0 * .pi / 180.0
            let radius = 35.0 - height/2 - 2 // Assuming view is 70x70

            tick.center = CGPoint(
                x: 35 + radius * sin(angle),
                y: 35 - radius * cos(angle)
            )
            tick.transform = CGAffineTransform(rotationAngle: angle)

            ticksContainer.addSubview(tick)
        }
    }

    private func setupLabels() {
        let labels = [
            (northLabel, "N", UIColor.systemRed),
            (southLabel, "S", UIColor.white.withAlphaComponent(0.9)),
            (eastLabel, "E", UIColor.white.withAlphaComponent(0.9)),
            (westLabel, "W", UIColor.white.withAlphaComponent(0.9))
        ]

        for (label, text, color) in labels {
            label.text = text
            label.textColor = color
            label.font = .systemFont(ofSize: 13, weight: .black)
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            dialView.addSubview(label)
        }

        NSLayoutConstraint.activate([
            northLabel.topAnchor.constraint(equalTo: dialView.topAnchor, constant: 10),
            northLabel.centerXAnchor.constraint(equalTo: dialView.centerXAnchor),

            southLabel.bottomAnchor.constraint(equalTo: dialView.bottomAnchor, constant: -10),
            southLabel.centerXAnchor.constraint(equalTo: dialView.centerXAnchor),

            eastLabel.trailingAnchor.constraint(equalTo: dialView.trailingAnchor, constant: -10),
            eastLabel.centerYAnchor.constraint(equalTo: dialView.centerYAnchor),

            westLabel.leadingAnchor.constraint(equalTo: dialView.leadingAnchor, constant: 10),
            westLabel.centerYAnchor.constraint(equalTo: dialView.centerYAnchor)
        ])
    }

    private func setupNeedle() {
        // Main needle stem
        needleView.backgroundColor = .systemRed
        needleView.layer.cornerRadius = 1.5
        needleView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(needleView)

        NSLayoutConstraint.activate([
            needleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            needleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            needleView.widthAnchor.constraint(equalToConstant: 2),
            needleView.heightAnchor.constraint(equalToConstant: 20)
        ])

        // Needle tip triangle (Professional Arrow)
        needleTip.backgroundColor = .systemRed
        needleTip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(needleTip)

        // Create a triangle path for the tip
        let shapeLayer = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 4, y: 0))
        path.addLine(to: CGPoint(x: 8, y: 8))
        path.addLine(to: CGPoint(x: 0, y: 8))
        path.close()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = UIColor.systemRed.cgColor
        needleTip.layer.addSublayer(shapeLayer)

        NSLayoutConstraint.activate([
            needleTip.centerXAnchor.constraint(equalTo: centerXAnchor),
            needleTip.bottomAnchor.constraint(equalTo: needleView.topAnchor, constant: 2),
            needleTip.widthAnchor.constraint(equalToConstant: 8),
            needleTip.heightAnchor.constraint(equalToConstant: 8)
        ])

        // Center glow dot
        centerDot.backgroundColor = .white
        centerDot.layer.cornerRadius = 2
        centerDot.layer.shadowColor = UIColor.white.cgColor
        centerDot.layer.shadowRadius = 3
        centerDot.layer.shadowOpacity = 0.8
        centerDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerDot)

        NSLayoutConstraint.activate([
            centerDot.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerDot.widthAnchor.constraint(equalToConstant: 4),
            centerDot.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    func updateRotation(yaw: Float) {
        // Yaw is in radians. We rotate the dial in the opposite direction.
        dialView.transform = CGAffineTransform(rotationAngle: CGFloat(-yaw))
    }

    @objc private func handleTap() {
        onNorthTap?()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .changed {
            let translation = gesture.translation(in: self)
            onPan?(translation)
            gesture.setTranslation(.zero, in: self)
        }
    }
}
