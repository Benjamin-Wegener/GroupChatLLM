# 🧠 GroupChatLLM
**A cross-platform toolkit for qualitative research via LLM-driven analysis, using `ik_llama.cpp` (a high-performance Llama.cpp fork)**  

![Build Status](https://img.shields.io/badge/build-passing-brightgreen) ![License](https://img.shields.io/badge/license-MIT-blue) ![Python](https://img.shields.io/badge/python-3.12+-green) ![Tkinter](https://img.shields.io/badge/tkinter-UI-blueviolet)  

---

## 📦 Installation

To install and build GroupChatLLM, follow these steps:

### 🐧 Linux (Ubuntu/Debian)

```bash
git clone https://github.com/Benjamin-Wegener/GroupChatLLM.git 
cd GroupChatLLM
chmod +x build.sh
./build.sh
```
This will:

Install required system packages
Clone ik_llama.cpp
Build the server with ARM64 optimizations if applicable
Download and requantize a sample GGUF model
Start the server on port 8080
👉 For more details, see: build.sh
## 🔍 **Overview**  
A lightweight, AI-powered lab for:  
- 🌐 Internet research integration (real-time web scraping/APIs)  
- 🧩 Dynamic model switching (expert GGUF models)  
- 📜 Context compression for long conversations  
- 🖥️ Cross-platform Tkinter UI (Windows/Linux)  

Built with:  
- [ik_llama.cpp](https://github.com/ikawrakow/ik_llama.cpp)
- Python 3.12+ and Tkinter (no browser dependencies)  
- Lightweight GGUF models (e.g., `Bitnet, Qwen3, DeepSeek...`)  

---

## 🚀 **Roadmap**  
<details>  
  <summary>Expand to view phases</summary>  
  <ul>  
    <li>✅ Phase 1: Compile <code>ik_llama.cpp</code></li>  
    <li>✅ Phase 2: Select and test GGUF models for research/code/translation</li>  
    <li>🚧 Phase 3: Implement web-scraping modules for real-time data retrieval</li>  
    <li>🏗️ Phase 4: Build Tkinter UI with model selection dropdowns</li>  
    <li>🏗️ Phase 5: Train GGUF model for context compression</li>  
  </ul>  
</details>  

---

## 📦 **Features**  
| Feature               | Description                                                                 |  
|-----------------------|-----------------------------------------------------------------------------|  
| 🌐 Internet Research  | Real-time web searches via `requests` + `BeautifulSoup` or SerpAPI          |  
| 🧠 Expert Models      | Switch between GGUF models for code, translation, or sentiment analysis     |  
| 💾 Context Compression| Summarize long chats into prompts using a lightweight GGUF model            |  
| 🖥️ Cross-Platform UI | Tkinter-based interface for Windows/Linux (no browser dependencies)         |  

---

## 🛠️ **Tech Stack**  
- **Backend**: `ik_llama.cpp`, Python 3.12+, GGUF models  
- **UI**: Tkinter (standard Python library)  
- **Internet Integration**: `requests`, `BeautifulSoup`, SerpAPI  
- **Packaging**: PyInstaller (Windows), AppImage (Linux)  

---

## 📜 **License**  
This project uses the [MIT License](https://opensource.org/licenses/MIT) for maximum flexibility .  
Author: Benjamin Wegener  


### 📚 **References**  
- `ik_llama.cpp` compilation guide: [llama.cpp GitHub](https://github.com/ggerganov/llama.cpp)  
- GGUF model quantization: [Phil Schmid's guide](https://www.philschmid.de/llama-cpp)  

