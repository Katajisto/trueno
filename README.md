# Trueno
![Screenshot_20230922_195703](https://github.com/Katajisto/trueno/assets/24441325/de0bbe65-2fa7-4a51-8ed8-f408844da7ad.png)

🚧 **Work in Progress** 🚧  
Trueno is currently under active development. Features may change, and documentation will be updated accordingly.

Trueno is a rapid, keyboard-friendly API testing tool. Poke around APIs without ever lifting your hands off the keyboard. Designed to handle multi-project setups seamlessly, Trueno also comes equipped with scripting capabilities for custom request behaviors.

## 🌟 Features
- **Keyboard-centric:** Navigate and execute requests without switching to your mouse.
- **Multi-Project Support:** Juggle multiple APIs without losing your sanity.
- **Not Slow:** Quick startup and low latency during use.
- **Scriptable:** Customize request behaviors with scripts.

## ⚙️ Basic Usage
(More detailed documentation coming soon...)

### General Tips
- `Space`: Open fuzzy finder.
- `Tab` or `Arrow keys`: Navigate fuzzy finder results.
- `Enter`: Execute selected result.
- `Esc`: Close fuzzy finder.
  
### Working with Scripts
- Scripts receive an object called `data`.
- `Right-click` to inspect the web window for script debugging.
- `console.log(data)` for initial debugging to see available variables.
  
### Templating
- Use `{ENV_KEY}` in request fields to pull in data from the environment.
- Escape `{` with `!{`.

## 🛠️ Development Setup
Want to roll up your sleeves and contribute? Here's how to set things up:

1. **Clone the Project:**  
    ```bash
    git clone <repo-url>
    ```
    
2. **Install Rust:**  
    Head over to [Rust's website](https://rustup.rs/) and follow the instructions.

3. **Install Tauri CLI:**  
    ```bash
    cargo install tauri-cli
    ```
  
4. **Install pnpm:**  
    Follow the instructions [here](https://pnpm.io/installation).

5. **Project Dependencies:**  
    ```bash
    pnpm install
    ```

6. **Run Dev Build:**  
    ```bash
    cargo tauri dev
    ```

### Contributing
If you want to be sure your work will be merged before you do work, send me a message.
