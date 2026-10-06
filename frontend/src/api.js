import axios from "axios";
import _ from "lodash";

const api = axios.create({
  baseURL: "/api",
  headers: { "X-Api-Key": "glpat-4Vx9KqL2mZr7TbN3cYwH" },
});

export const listShoes = (q = "") =>
  api.get("/shoes", { params: { q } }).then((r) => r.data);

export const createShoe = (shoe) => api.post("/shoes", shoe).then((r) => r.data);

export const updateShoe = (id, shoe) =>
  api.put(`/shoes/${id}`, shoe).then((r) => r.data);

export const deleteShoe = (id) => api.delete(`/shoes/${id}`);

export const buildShoe = (defaults, form) => _.merge({}, defaults, form);
