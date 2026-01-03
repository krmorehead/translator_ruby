import { describe, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { daedalusApi } from "../daedalusApi";

describe("daedalusApi", () => {
  speed_profile("fast")("has createPlan method", () => {
    expect(daedalusApi.createPlan).toBeDefined();
    expect(typeof daedalusApi.createPlan).toBe("function");
  });

  speed_profile("fast")("createPlan returns a promise", () => {
    // Don't await - just verify it returns a promise
    // Actual API calls are tested in E2E tests
    const promise = daedalusApi.createPlan({ goal: "test", path: "/test", context: {} });
    
    expect(promise).toBeInstanceOf(Promise);
    
    // Clean up the promise to avoid unhandled rejection
    promise.catch(() => {});
  });
});

