# Time Vibe Landing Page

This is the landing page for Time Vibe, a smart time tracking application.

## Getting Started

To preview the landing page locally:

1. Navigate to the landing directory:
```bash
cd landing
```

2. Install dependencies:
```bash
npm install
```

3. Start the preview server:
```bash
npm run preview
```

4. Open your browser and visit:
```
http://localhost:3000
```

## Deployment

This landing page is optimized for deployment on Vercel. Simply connect your repository to Vercel and configure the build settings to use the `landing` directory as the root.

## Google Form Integration

To update the Google Form link for the "Join Waitlist" buttons:

1. Open `script.js`
2. Replace the placeholder URL with your actual Google Form link:
```javascript
const GOOGLE_FORM_LINK = 'https://docs.google.com/forms/d/e/YOUR_FORM_ID/viewform';
```