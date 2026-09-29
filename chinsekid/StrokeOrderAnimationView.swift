import SwiftUI
import WebKit

struct StrokeOrderAnimationView: UIViewRepresentable {
    let strokes: [String]
    let medians: [[[Double]]]
    let replayID: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        context.coordinator.strokes = strokes
        context.coordinator.medians = medians
        context.coordinator.replayID = replayID
        webView.loadHTMLString(Self.html(for: strokes, medians: medians), baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.strokes != strokes || context.coordinator.medians != medians {
            context.coordinator.strokes = strokes
            context.coordinator.medians = medians
            context.coordinator.replayID = replayID
            webView.loadHTMLString(Self.html(for: strokes, medians: medians), baseURL: nil)
        } else if context.coordinator.replayID != replayID {
            context.coordinator.replayID = replayID
            webView.evaluateJavaScript("playStrokes()")
        }
    }

    private static func html(for strokes: [String], medians: [[[Double]]]) -> String {
        guard let strokeData = try? JSONSerialization.data(withJSONObject: strokes),
              let medianData = try? JSONSerialization.data(withJSONObject: medians) else {
            return "<html><body></body></html>"
        }
        let strokesBase64 = strokeData.base64EncodedString()
        let mediansBase64 = medianData.base64EncodedString()
        return """
        <!doctype html>
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
          * { box-sizing: border-box; }
          html, body { margin: 0; width: 100%; height: 100%; background: transparent; overflow: hidden; }
          #sequence { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 18px 8px; padding: 18px 2px 2px; }
          .step { position: relative; aspect-ratio: 1; border: 1.5px solid #59c9e5; border-radius: 2px; background: #fff; }
          .step::before, .step::after { content: ''; position: absolute; z-index: 1; pointer-events: none; }
          .step::before { left: 0; right: 0; top: 50%; border-top: 1px dashed #83d8e9; }
          .step::after { top: 0; bottom: 0; left: 50%; border-left: 1px dashed #83d8e9; }
          .number { position: absolute; left: 1px; top: -15px; color: #ec746e; font: 700 12px/13px -apple-system, sans-serif; }
          svg { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; opacity: 0; }
          .step.active svg, .step.complete svg { opacity: 1; }
          path { transform-box: fill-box; transform-origin: center; }
          .step.active { border-color: #f18b52; box-shadow: 0 0 0 2px #f6bd75; }
        </style></head><body>
        <div id="sequence" role="img" aria-label="汉字笔顺分步示意"></div>
        <script>
          const strokeData = JSON.parse(atob('\(strokesBase64)'));
          const medianData = JSON.parse(atob('\(mediansBase64)'));
          const sequence = document.getElementById('sequence');
          let replayTimer = null;
          let replayToken = 0;
          const traces = [];
          const frames = strokeData.map((_, stepIndex) => {
            const frame = document.createElement('div');
            frame.className = 'step';
            const number = document.createElement('span');
            number.className = 'number';
            number.textContent = String(stepIndex + 1);
            frame.appendChild(number);

            const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            svg.setAttribute('viewBox', '0 0 1024 1024');
            svg.setAttribute('aria-hidden', 'true');
            const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
            group.setAttribute('transform', 'scale(1, -1) translate(0, -900)');
            strokeData.slice(0, stepIndex).forEach((pathData) => {
              const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
              path.setAttribute('d', pathData);
              // Earlier strokes stay visible as a quiet guide. The current
              // stroke below is the only one emphasized in red.
              path.setAttribute('fill', '#9299a3');
              path.setAttribute('opacity', '1');
              group.appendChild(path);
            });

            const currentOutline = strokeData[stepIndex];
            const median = medianData[stepIndex] || [];
            if (currentOutline && median.length > 1) {
              const maskID = 'stroke-mask-' + stepIndex;
              const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
              const mask = document.createElementNS('http://www.w3.org/2000/svg', 'mask');
              mask.setAttribute('id', maskID);
              mask.setAttribute('maskUnits', 'userSpaceOnUse');
              mask.setAttribute('x', '-100');
              mask.setAttribute('y', '-200');
              mask.setAttribute('width', '1224');
              mask.setAttribute('height', '1224');
              const blackBackground = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
              blackBackground.setAttribute('x', '-100');
              blackBackground.setAttribute('y', '-200');
              blackBackground.setAttribute('width', '1224');
              blackBackground.setAttribute('height', '1224');
              blackBackground.setAttribute('fill', 'black');

              const trace = document.createElementNS('http://www.w3.org/2000/svg', 'path');
              const medianPath = median.map((point, pointIndex) =>
                (pointIndex === 0 ? 'M ' : 'L ') + point[0] + ' ' + point[1]
              ).join(' ');
              trace.setAttribute('d', medianPath);
              trace.setAttribute('fill', 'none');
              trace.setAttribute('stroke', 'white');
              trace.setAttribute('stroke-width', '220');
              trace.setAttribute('stroke-linecap', 'round');
              trace.setAttribute('stroke-linejoin', 'round');
              trace.classList.add('trace');
              mask.appendChild(blackBackground);
              mask.appendChild(trace);
              defs.appendChild(mask);
              group.appendChild(defs);

              const currentPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
              currentPath.setAttribute('d', currentOutline);
              currentPath.setAttribute('fill', '#c62f45');
              currentPath.setAttribute('mask', 'url(#' + maskID + ')');
              group.appendChild(currentPath);
              traces[stepIndex] = trace;
            }
            svg.appendChild(group);
            frame.appendChild(svg);
            sequence.appendChild(frame);
            return frame;
          });
          function playStrokes() {
            const token = ++replayToken;
            if (replayTimer !== null) clearTimeout(replayTimer);
            sequence.classList.remove('playing');
            frames.forEach((frame) => {
              frame.classList.remove('active');
              frame.classList.remove('complete');
              frame.querySelectorAll('path').forEach((path) => {
                path.getAnimations().forEach((animation) => animation.cancel());
              });
            });
            sequence.classList.add('playing');

            let frameIndex = 0;
            function playNextFrame() {
              if (token !== replayToken) return;
              if (frameIndex >= frames.length) {
                sequence.classList.remove('playing');
                frames.forEach((frame) => frame.classList.remove('active'));
                replayTimer = null;
                return;
              }

              const frame = frames[frameIndex];
              frame.classList.add('active');
              const trace = traces[frameIndex];
              let strokeDuration = 1100;
              if (trace) {
                const length = trace.getTotalLength();
                strokeDuration = Math.min(1700, Math.max(900, length * 1.15));
                trace.style.strokeDasharray = String(length);
                trace.style.strokeDashoffset = String(length);
                trace.animate(
                  [
                    { strokeDashoffset: length },
                    { strokeDashoffset: 0 }
                  ],
                  { duration: strokeDuration, fill: 'forwards', easing: 'linear' }
                );
              }

              replayTimer = setTimeout(() => {
                frame.classList.remove('active');
                frame.classList.add('complete');
                frameIndex += 1;
                playNextFrame();
              }, strokeDuration + 360);
            }
            playNextFrame();
          }
          playStrokes();
        </script></body></html>
        """
    }

    final class Coordinator {
        var strokes: [String] = []
        var medians: [[[Double]]] = []
        var replayID = -1
    }
}
