//
//  ProbabilisticAssociation.swift
//  MBatmaN
//
//  Probabilistic Evidence Accumulation (PEA) for robust distance-wall association.
//

import Foundation

/// Uses Probabilistic Evidence Accumulation to determine the most likely wall distance
/// from a set of noisy echo candidates.
nonisolated final class ProbabilisticAssociation: @unchecked Sendable {
    
    // MARK: - Constants
    private let minDist: Float = 0.3
    private let maxDist: Float = 5.0
    private let resolution: Float = 0.02 // 2 cm bins
    private let numBins: Int
    
    // Tuning parameters
    private let decayFactor: Float = 0.85
    private let spatialSigma: Float = 0.05 // 5 cm spread for evidence
    private let maxEvidence: Float = 10.0  // Cap to prevent infinite accumulation
    
    // MARK: - State
    private var evidenceGrid: [Float]
    
    init() {
        self.numBins = Int(ceil((maxDist - minDist) / resolution)) + 1
        self.evidenceGrid = [Float](repeating: 0.0, count: self.numBins)
    }
    
    // MARK: - Public API
    
    /// Updates the evidence grid with new candidates and returns the most probable distance.
    /// - Parameter candidates: Array of [distance, amplitude] pairs
    /// - Returns: The distance with the highest accumulated evidence
    func update(candidates: [[Float]]) -> Float {
        // 1. Decay past evidence
        for i in 0..<numBins {
            evidenceGrid[i] *= decayFactor
        }
        
        // 2. Accumulate new evidence
        for candidate in candidates {
            let d = candidate[0]
            let amp = max(0, candidate[1]) // Ensure positive amplitude for evidence
            
            guard d >= minDist && d <= maxDist else { continue }
            
            // Spread evidence around the candidate distance using a Gaussian kernel
            let centerIdx = Int(round((d - minDist) / resolution))
            
            // 3 sigma rule for the kernel window (3 * 0.05 / 0.02 = 7.5 bins)
            let window = 8
            let startIdx = max(0, centerIdx - window)
            let endIdx = min(numBins - 1, centerIdx + window)
            
            for i in startIdx...endIdx {
                let binDist = minDist + Float(i) * resolution
                let diff = binDist - d
                
                // Gaussian weight
                let weight = exp(-(diff * diff) / (2 * spatialSigma * spatialSigma))
                
                evidenceGrid[i] += amp * weight
                
                // Cap evidence to prevent run-away values from consistently loud echoes
                if evidenceGrid[i] > maxEvidence {
                    evidenceGrid[i] = maxEvidence
                }
            }
        }
        
        // 3. Extract the most probable distance (peak of the evidence grid)
        var maxEv: Float = -1
        var bestIdx: Int = 0
        
        for i in 0..<numBins {
            if evidenceGrid[i] > maxEv {
                maxEv = evidenceGrid[i]
                bestIdx = i
            }
        }
        
        // If no evidence at all, return default 0 or minDist
        if maxEv <= 0 {
            return 0
        }
        
        let finalDist = minDist + Float(bestIdx) * resolution
        return finalDist
    }
}
