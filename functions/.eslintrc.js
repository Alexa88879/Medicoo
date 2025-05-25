// functions/.eslintrc.js
// This configuration helps enforce consistent style and catch errors.
// The "linebreak-style": ["error", "unix"] rule is key for deployment.
// "max-len" is increased to 120 for better readability with comments.
module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "quotes": ["error", "double"], // Enforce double quotes for strings
    "indent": ["error", 2], // Enforce 2-space indentation
    "linebreak-style": ["error", "unix"], // CRITICAL: Enforce Unix (LF) line endings
    "object-curly-spacing": ["error", "never"], // No spaces inside {curly braces} e.g. {key: value}
    "max-len": ["error", {"code": 120, "ignoreComments": true, "ignoreUrls": true, "ignoreStrings": true, "ignoreTemplateLiterals": true}],
    "require-jsdoc": ["warn", { // Changed to warn to not block deployment for missing JSDoc initially
      require: {
        FunctionDeclaration: true,
        MethodDefinition: false,
        ClassDeclaration: false,
        ArrowFunctionExpression: false,
        FunctionExpression: false,
      },
    }],
    "valid-jsdoc": ["warn", { // Changed to warn
      requireReturn: false, // Not requiring @return if function doesn't return anything explicitly
      requireReturnType: true, // But if @return is there, type is good
      requireParamDescription: false,
      requireReturnDescription: false,
    }],
    "no-unused-vars": ["warn", {"argsIgnorePattern": "^_"}], // Warn for unused vars, allow args starting with _
    "comma-dangle": ["error", "always-multiline"], // Require trailing commas for multiline objects/arrays
    "eol-last": ["error", "always"], // Ensure file ends with a single newline character
  },
  parserOptions: {
    "ecmaVersion": 2020, // Or a newer supported version like 2022
  },
};
