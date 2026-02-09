# Claw-Bench Paper

## Paper Title
**Claw-Bench: A Comprehensive Benchmark Suite for Evaluating LLM Agent Capabilities in Personal AI Assistants**

## Abstract
We present Claw-Bench, a comprehensive benchmark suite for evaluating Large Language Model (LLM) agent capabilities in the context of personal AI assistants. Using the open-source OpenClaw/Clawdbot framework as our evaluation platform, we develop 33 tests across five categories: core agent functionality, extended tool usage, real-world use cases, robustness, and stress testing. Our empirical evaluation of six models available through AWS Bedrock reveals significant performance disparities, with Mistral Large 3 achieving a 97% pass rate while being 40% cheaper than alternatives.

## Files
- `clawbench-paper.tex` - LaTeX source
- `clawbench-paper.pdf` - Compiled PDF (generate with pdflatex)

## Building the PDF

### Option 1: Overleaf (Recommended)
1. Go to https://www.overleaf.com
2. Create new project → Upload project
3. Upload `clawbench-paper.tex`
4. Click "Recompile" to generate PDF

### Option 2: Local LaTeX
```bash
cd paper
pdflatex clawbench-paper.tex
pdflatex clawbench-paper.tex  # Run twice for references
```

### Option 3: Docker
```bash
docker run --rm -v $(pwd):/workdir texlive/texlive pdflatex clawbench-paper.tex
```

## Publication Options

### Primary: arXiv (cs.AI or cs.LG)
- **URL**: https://arxiv.org/submit
- **Category**: cs.AI (Artificial Intelligence) or cs.LG (Machine Learning)
- **Requirements**:
  - Academic/research institution email recommended
  - First-time submitters need endorsement
  - No peer review required for empirical papers with original results
- **Timeline**: 1-2 days for moderation

### Alternative: Papers With Code
- **URL**: https://paperswithcode.com/
- **Advantage**: Direct link to GitHub repo, benchmark leaderboards
- **Process**: Submit after arXiv posting

### Alternative: OpenReview
- **URL**: https://openreview.net/
- **Advantage**: Open peer review, community feedback
- **Note**: Often used for conference submissions

### Alternative: TechRxiv
- **URL**: https://www.techrxiv.org/
- **Focus**: Engineering and technology preprints
- **Advantage**: IEEE-affiliated, good for applied research

### Alternative: OSF Preprints
- **URL**: https://osf.io/preprints/
- **Advantage**: Supports supplementary data, code
- **Note**: Good for reproducibility-focused work

## Submission Checklist

### For arXiv
- [ ] Register at arxiv.org with institutional email
- [ ] Get endorsement (if first-time submitter)
- [ ] Ensure LaTeX compiles without errors
- [ ] Include all figures as PDF/PNG
- [ ] Add license (recommend CC-BY 4.0)
- [ ] Submit and wait for moderation

### For Papers With Code
- [ ] Post to arXiv first
- [ ] Create benchmark entry
- [ ] Link to GitHub repository
- [ ] Add leaderboard with model results

## Citation
```bibtex
@article{morris2026clawbench,
  title={Claw-Bench: A Comprehensive Benchmark Suite for Evaluating LLM Agent Capabilities in Personal AI Assistants},
  author={Morris, Alex},
  journal={arXiv preprint},
  year={2026}
}
```

## Key Findings

| Model | Pass Rate | Cost Savings vs Kimi K2 |
|-------|-----------|-------------------------|
| Mistral Large 3 | 97% | 40% cheaper |
| Kimi K2 | ~40% | Baseline |
| Amazon Nova | ~12% | Cheapest but broken |

## Contact
- Author: Alex Morris
- Email: a@tribecode.ai
- Organization: Tribe Inc.
