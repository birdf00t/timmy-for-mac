import AVFoundation
import AppKit
import Vision

/// 카메라로 눈 깜빡임을 본다.
///
/// 개인정보에 대하여: 프레임은 이 프로세스 안에서만 쓰이고 저장하거나 내보내지 않는다.
/// 남기는 결과는 "깜빡였다"는 신호 하나뿐이며, 영상이나 얼굴 특징 자체는
/// 프레임을 처리한 직후 버린다.
final class FaceMonitor: NSObject {

    /// 눈을 깜빡였을 때.
    var onBlink: (() -> Void)?
    /// 카메라를 쓸 수 없을 때 (권한 거부, 장치 없음 등).
    var onFailure: ((String) -> Void)?

    private(set) var isRunning = false

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "timmy.face", qos: .utility)
    private var configured = false

    /// 프레임을 이 간격으로만 본다. 눈 깜빡임은 100~150ms 라 너무 띄우면 놓치고,
    /// 너무 촘촘하면 카메라와 Vision 이 전력을 많이 먹는다.
    private let interval: CFTimeInterval = 1.0 / 15.0
    private var lastProcessed: CFTimeInterval = 0

    // MARK: - 눈 깜빡임

    /// 평상시 눈이 얼마나 떠 있는지. 거리·조명이 바뀌어도 기준이 따라가도록 천천히 갱신한다.
    private var opennessAverage: CGFloat?
    private var lastBlinkAt: CFTimeInterval = 0
    private let blinkRefractory: CFTimeInterval = 0.25

    // MARK: - 시작 / 정지

    func start() {
        guard !isRunning else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureAndRun()
                    } else {
                        self.onFailure?("카메라 접근이 거부되었습니다.")
                    }
                }
            }
        case .denied, .restricted:
            onFailure?("시스템 설정 → 개인정보 보호 및 보안 → 카메라 에서 Timmy 를 켜주세요.")
        @unknown default:
            onFailure?("카메라를 쓸 수 없습니다.")
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        queue.async { [session] in session.stopRunning() }
        opennessAverage = nil
    }

    private func configureAndRun() {
        guard !configured else {
            queue.async { [session] in session.startRunning() }
            isRunning = true
            return
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video) else {
            onFailure?("카메라를 찾지 못했습니다.")
            return
        }

        session.beginConfiguration()
        // 얼굴 위치와 눈 모양만 보면 되므로 낮은 해상도로 충분하다.
        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        } else {
            session.sessionPreset = .medium
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                onFailure?("카메라를 열 수 없습니다.")
                return
            }
            session.addInput(input)
        } catch {
            session.commitConfiguration()
            onFailure?("카메라를 열 수 없습니다: \(error.localizedDescription)")
            return
        }

        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            onFailure?("카메라 출력을 붙일 수 없습니다.")
            return
        }
        session.addOutput(output)
        session.commitConfiguration()

        configured = true
        isRunning = true
        queue.async { [session] in session.startRunning() }
    }

    // MARK: - 분석

    private func analyze(_ face: VNFaceObservation, at now: CFTimeInterval) {
        // 눈 깜빡임 — 눈 landmark 의 세로/가로 비가 갑자기 줄면 감은 것이다.
        guard let openness = eyeOpenness(face) else { return }
        guard let average = opennessAverage else {
            opennessAverage = openness
            return
        }

        if openness < average * 0.62, now - lastBlinkAt > blinkRefractory {
            lastBlinkAt = now
            DispatchQueue.main.async { self.onBlink?() }
        }
        opennessAverage = average * 0.94 + openness * 0.06
    }

    /// 양쪽 눈의 세로/가로 비 평균. 눈을 감으면 세로가 납작해져 값이 떨어진다.
    private func eyeOpenness(_ face: VNFaceObservation) -> CGFloat? {
        guard let landmarks = face.landmarks else { return nil }

        var ratios: [CGFloat] = []
        for region in [landmarks.leftEye, landmarks.rightEye] {
            guard let points = region?.normalizedPoints, points.count > 2 else { continue }
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max() else { continue }
            let width = maxX - minX
            guard width > 0.0001 else { continue }
            ratios.append((maxY - minY) / width)
        }

        guard !ratios.isEmpty else { return nil }
        return ratios.reduce(0, +) / CGFloat(ratios.count)
    }
}

// MARK: - 프레임 수신

extension FaceMonitor: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastProcessed >= interval else { return }
        lastProcessed = now

        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let face = request.results?.first else { return }
        analyze(face, at: now)
    }
}
