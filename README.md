# Academic Nexus 🎓

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Sarvam AI](https://img.shields.io/badge/Sarvam_AI-1E1E1E?style=for-the-badge&logo=openai&logoColor=white)

**Academic Nexus** is a proactive student dashboard and real-time academic management platform. Built to empower students with data-driven insights, it features intelligent attendance tracking, secure cloud storage for academic records, and an elite multimodal AI tutor capable of processing both text and complex academic images.

**Live Application:** [https://academic-nexus-db32d.web.app](https://academic-nexus-db32d.web.app)

---

## ✨ Core Features

*   **Multimodal AI Advisor:** Integrated with Sarvam AI's advanced models (`sarvam-105b` for text and `gemma4` for vision). The AI acts as an interactive tutor, reading uploaded screenshots of assignments or notes and breaking down complex concepts step-by-step.
*   **Secure Private Vaults:** Powered by Firebase Cloud Firestore. Every user gets a strict, isolated data environment protected by robust backend Security Rules, ensuring academic data is completely private and permanently saved.
*   **Real-Time Authentication:** Seamless and secure user onboarding managed via Firebase Authentication.
*   **Proactive Attendance Tracking:** Dynamic tracking of target versus current attendance percentages for individual subjects.
*   **Cross-Platform Ready:** Built with a Flutter frontend and compiled seamlessly for the Web with progressive web app (PWA) capabilities.

---

## 🛠 Tech Stack

*   **Frontend:** Flutter (Dart)
*   **Backend as a Service (BaaS):** Firebase (Authentication, Firestore, Hosting)
*   **AI Integration:** Sarvam AI REST API (Multimodal Endpoints)
*   **Environment Management:** `flutter_dotenv`

---

## 🚀 Getting Started

Follow these instructions to set up the project locally on your machine.

### Prerequisites

*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
*   [Firebase CLI](https://firebase.google.com/docs/cli)
*   A Sarvam AI API Key

### Installation

1.  **Clone the repository**
    ```bash
    git clone [https://github.com/Krishna2006-babu/academic-nexus.git](https://github.com/Krishna2006-babu/academic-nexus.git)
    cd academic-nexus
    ```

2.  **Install dependencies**
    ```bash
    flutter pub get
    ```

3.  **Environment Setup**
    *   Create an `assets` folder in the root directory if it doesn't exist.
    *   Inside the `assets` folder, create a file named `.env`.
    *   Add your Sarvam API key to the `.env` file:
        ```env
        SARVAM_API_KEY=your_api_key_here
        ```
    *   *Note: The `assets/.env` file is included in `.gitignore` to prevent secret leakage.*

4.  **Run the application locally**
    ```bash
    flutter run -d edge
    ```
    *(You can replace `edge` with `chrome` or your preferred local web debugger).*

---

## ☁️ Deployment

This project is configured for Firebase Hosting. To deploy new changes to production:

1.  **Clean and build the web bundle:**
    ```bash
    flutter clean
    flutter build web
    ```

2.  **Deploy to Firebase:**
    ```bash
    firebase deploy --only hosting
    ```
    *Note: A hard refresh (`Ctrl + F5`) may be required in the browser after deployment to clear the Service Worker cache.*

---

## 🔒 Security Architecture

Academic Nexus utilizes strict Firebase Firestore Security Rules to prevent unauthorized data access. 
*   **Isolated Data:** The database enforces rules preventing users from reading or writing to document paths that do not match their verified Firebase Authentication UID.
*   **API Security:** API keys are injected dynamically via environment variables on application boot and are never committed to the public version control history.

---

## 👨‍💻 Developer Information

Developed and maintained by **Krishna Sharma**  
*B.Tech in Electronics and Communication Engineering | NIT Silchar*