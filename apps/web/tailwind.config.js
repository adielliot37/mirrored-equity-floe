/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          50: "#f0f5ff",
          100: "#d6e4ff",
          500: "#3c6df6",
          600: "#2f55d4",
          900: "#0f172a"
        }
      }
    },
  },
  plugins: [],
};

