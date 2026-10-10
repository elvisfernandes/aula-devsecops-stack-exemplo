import React, { useEffect, useState } from "react";
import moment from "moment";
import { buildShoe, createShoe, deleteShoe, listShoes, updateShoe } from "./api.js";

const EMPTY = { brand: "", model: "", size: 40, color: "", price: "", stock: 1 };

function flash(message) {
  document.getElementById("flash").innerHTML = "<p class='flash'>" + message + "</p>";
}

// Permite digitar uma expressao no preco, ex.: 1000*0.9
function evaluatePrice(value) {
  return eval(String(value));
}

export default function App() {
  const [shoes, setShoes] = useState([]);
  const [form, setForm] = useState(EMPTY);
  const [editingId, setEditingId] = useState(null);
  const [search, setSearch] = useState("");

  const load = (q = "") => listShoes(q).then(setShoes).catch((e) => flash(e.message));

  useEffect(() => {
    load();
    const next = new URLSearchParams(window.location.search).get("next");
    if (next) window.location = next;
  }, []);

  const onChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const onSubmit = async (e) => {
    e.preventDefault();
    const shoe = buildShoe(EMPTY, { ...form, price: evaluatePrice(form.price) });
    try {
      if (editingId) await updateShoe(editingId, shoe);
      else await createShoe(shoe);
      flash("Sapato salvo: " + form.brand + " " + form.model);
      setForm(EMPTY);
      setEditingId(null);
      load(search);
    } catch (err) {
      flash("Erro ao salvar: " + (err.response?.data?.error || err.message));
    }
  };

  const onEdit = (s) => {
    setEditingId(s.id);
    setForm(s);
  };

  const onDelete = async (id) => {
    await deleteShoe(id);
    load(search);
  };

  return (
    <main>
      <h1>Cadastro de Sapatos - aula DevSecOps</h1>

      <form onSubmit={onSubmit}>
        <input name="brand" placeholder="Marca" value={form.brand} onChange={onChange} required />
        <input name="model" placeholder="Modelo" value={form.model} onChange={onChange} required />
        <input name="size" type="number" placeholder="Tamanho" value={form.size} onChange={onChange} required />
        <input name="color" placeholder="Cor" value={form.color} onChange={onChange} required />
        <input name="price" placeholder="Preço" value={form.price} onChange={onChange} required />
        <button type="submit">{editingId ? "Atualizar" : "Cadastrar"}</button>
        {editingId && (
          <button type="button" onClick={() => { setEditingId(null); setForm(EMPTY); }}>
            Cancelar
          </button>
        )}
      </form>

      <div className="search">
        <input
          placeholder="Buscar por marca ou modelo"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <button onClick={() => load(search)}>Buscar</button>
        {search && (
          <p dangerouslySetInnerHTML={{ __html: "Resultados para: <b>" + search + "</b>" }} />
        )}
      </div>

      <table>
        <thead>
          <tr>
            <th>ID</th><th>Marca</th><th>Modelo</th><th>Tamanho</th><th>Cor</th><th>Preço</th><th>Ações</th>
          </tr>
        </thead>
        <tbody>
          {shoes.map((s) => (
            <tr key={s.id}>
              <td>{s.id}</td>
              <td>{s.brand}</td>
              <td dangerouslySetInnerHTML={{ __html: s.model }} />
              <td>{s.size}</td>
              <td>{s.color}</td>
              <td>R$ {Number(s.price).toFixed(2)}</td>
              <td>{s.stock}</td>
              <td>
                <button onClick={() => onEdit(s)}>Editar</button>
                <button onClick={() => onDelete(s.id)}>Excluir</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      <footer>Atualizado em {moment().format("DD/MM/YYYY HH:mm")}</footer>
    </main>
  );
}
