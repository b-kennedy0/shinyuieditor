import { generatePythonOutputBinding } from "./generate_output_binding";

test("Can generate output bindings from simple text", () => {
  const expected_output = `@output
@render.plot(alt="A plot")
def MyPlot():
    # Not yet implemented
    # With a new line`;
  expect(
    generatePythonOutputBinding("MyPlot", {
      fn_name: `@render.plot(alt="A plot")`,
      fn_body: `# Not yet implemented\n# With a new line`,
    })
  ).toBe(expected_output);
});
