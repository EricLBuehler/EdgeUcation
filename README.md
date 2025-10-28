# Edge(u)cation: Cutting-edge multimodal LLMs on the edge with mistral.rs, using F8Q8.

## Structure
- `ios_bridge`: Rust and C++ code connecting mistral.rs (i.e. UQFF/Metal codes) to the Swift frontend
- `ios_vlm`: Multilingual Swift frontend.

## Installation
Installation is designed to work on a Mac (Apple silicon) machine.

0) Install dependencies:
   1) Rust (https://rust-lang.org/tools/install/)
   2) Install XCode developer tools (https://mac.install.guide/commandlinetools/)
   3) Enable developer mode on your iphone (https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device) 
   
1) Run the following Terminal commands to install Edge(u)cation:

```
cd ios_bridge
./build.sh
cd ..
```

2) Then, open `ios_vlm` in XCode and install the app by selecting the build target to be either your iPhone or a simulator.

**Abstract**:

Could a personalized, portable AI tutor transform education and improve outcomes for students in disadvantaged communities? Advancements in open-source large language models (LLMs), particularly multimodal models that can understand images and text, enable AI-driven personalized learning by giving students rapid and personalized feedback while addressing privacy concerns. However, running these models on consumer devices like a cell phone remains cost-prohibitive. I hypothesize that LLMs can be made more efficient for use on a phone through an improved algorithm that decomposes the parameters of a neural network into two parts, one of which has a certain range that we can exploit to reduce memory footprint. This would allow me to fit a powerful LLM onto a phone while retaining high accuracy. I found that my novel post-training quantization method reduces memory footprint for a cutting-edge 8 billion parameter model from 16 GB RAM to 8.16 GB RAM, a 49\% reduction in model size. Integrated into my custom inference engine written in Rust called mistral.rs, this approach powers Edge(u)cation, an AI tutor app I created for mobile devices. To validate its impact, I then deployed Edge(u)cation in several example settings including math and engineering education experiments through real-time, AI-driven feedback. In conclusion, this work demonstrates a scalable, cost-effective solution for personalized learning, fostering STEM engagement in under-resourced communities. All codes and models are published for anyone to access, use, and build on.

<img src = https://github.com/user-attachments/assets/4c575176-105c-47b2-a620-e8a008f7f135 height = 300></img>

Source: https://commons.wikimedia.org/wiki/File:Classroom_Picture_1.JPG

## F8Q8: 8-bit RTN-based blockwise nested quantization
F8E4M3 diagram:

<img src = https://github.com/user-attachments/assets/5de826f2-5c50-4a75-b9dd-f54b9e3e8d46 height = 75></img>

F8Q8:
- Uses a block size of 32
- Is a form of 8-bit RTN quantization without any zero point/bias
- Takes advantage of the observed range of the RTN scale $d$, to compress it into [F8E4M3](https://github.com/EricLBuehler/float8).
- Integrated with UQFF in mistral.rs
