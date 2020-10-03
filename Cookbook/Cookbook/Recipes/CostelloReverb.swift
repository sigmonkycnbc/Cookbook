import AudioKit
import AVFoundation
import SwiftUI

struct CostelloReverbData {
    var feedback: AUValue = 0.6
    var cutoffFrequency: AUValue = 4_000.0
    var rampDuration: AUValue = 0.02
    var balance: AUValue = 0.5
}

class CostelloReverbConductor: ObservableObject, ProcessesPlayerInput {

    let engine = AudioEngine()
    let player = AudioPlayer()
    let reverb: CostelloReverb
    let dryWetMixer: DryWetMixer
    let playerPlot: NodeOutputPlot
    let reverbPlot: NodeOutputPlot
    let mixPlot: NodeOutputPlot
    let buffer: AVAudioPCMBuffer

    init() {
        let url = Bundle.main.resourceURL?.appendingPathComponent("Samples/beat.aiff")
        let file = try! AVAudioFile(forReading: url!)
        buffer = try! AVAudioPCMBuffer(file: file)!

        reverb = CostelloReverb(player)
        dryWetMixer = DryWetMixer(player, reverb)
        playerPlot = NodeOutputPlot(player)
        reverbPlot = NodeOutputPlot(reverb)
        mixPlot = NodeOutputPlot(dryWetMixer)
        engine.output = dryWetMixer

        playerPlot.plotType = .rolling
        playerPlot.shouldFill = true
        playerPlot.shouldMirror = true
        playerPlot.setRollingHistoryLength(128)
        reverbPlot.plotType = .rolling
        reverbPlot.color = .blue
        reverbPlot.shouldFill = true
        reverbPlot.shouldMirror = true
        reverbPlot.setRollingHistoryLength(128)
        mixPlot.color = .purple
        mixPlot.shouldFill = true
        mixPlot.shouldMirror = true
        mixPlot.plotType = .rolling
        mixPlot.setRollingHistoryLength(128)
    }

    @Published var data = CostelloReverbData() {
        didSet {
            reverb.$feedback.ramp(to: data.feedback, duration: data.rampDuration)
            reverb.$cutoffFrequency.ramp(to: data.cutoffFrequency, duration: data.rampDuration)
            dryWetMixer.balance = data.balance
        }
    }

    func start() {
        playerPlot.start()
        reverbPlot.start()
        mixPlot.start()

        do {
            try engine.start()
            // player stuff has to be done after start
            player.scheduleBuffer(buffer, at: nil, options: .loops)
        } catch let err {
            Log(err)
        }
    }

    func stop() {
        engine.stop()
    }
}

struct CostelloReverbView: View {
    @ObservedObject var conductor = CostelloReverbConductor()

    var body: some View {
        ScrollView {
            PlayerControls(conductor: conductor)
            ParameterSlider(text: "Feedback",
                            parameter: self.$conductor.data.feedback,
                            range: 0.0...1.0,
                            units: "Percent")
            ParameterSlider(text: "Cutoff Frequency",
                            parameter: self.$conductor.data.cutoffFrequency,
                            range: 12.0...20_000.0,
                            units: "Hertz")
            ParameterSlider(text: "Balance",
                            parameter: self.$conductor.data.balance,
                            range: 0...1,
                            units: "%")
            DryWetMixPlotsView(dry: conductor.playerPlot, wet: conductor.reverbPlot, mix: conductor.mixPlot)
        }
        .padding()
        .navigationBarTitle(Text("Costello Reverb"))
        .onAppear {
            self.conductor.start()
        }
        .onDisappear {
            self.conductor.stop()
        }
    }
}

struct CostelloReverb_Previews: PreviewProvider {
    static var previews: some View {
        CostelloReverbView()
    }
}
