import React, { useEffect, useState } from "react";
import moment from "moment";
import { buildShoe, createShoe, deleteShoe, listShoes, updateShoe } from "./api.js";

const EMPTY = { brand: "", model: "", size: 40, color: "", price: "", stock: 1 };

function parsePrice(value) {
  const price = Number(String(value).replace(",", "."));
  if (!Number.isFinite(price) || price < 0) throw new Error("Preço inválido");
  return price;
}

export default function App() {
  const [shoes, setShoes] = useState([]);
  const [form, setForm] = useState(EMPTY);
  const [editingId, setEditingId] = useState(null);
  const [search, setSearch] = useState("");
  const [message, setMessage] = useState("");

  const load = (q = "") => listShoes(q).then(setShoes).catch((e) => setMessage(e.message));

  useEffect(() => {
    load();
  }, []);

  const onChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

  const onSubmit = async (e) => {
    e.preventDefault();
    try {
      const shoe = buildShoe(EMPTY, {
        ...form,
        size: Number(form.size),
        stock: Number(form.stock),
        price: parsePrice(form.price),
      });
      if (editingId) await updateShoe(editingId, shoe);
      else await createShoe(shoe);
      setMessage("Sapato salvo: " + form.brand + " " + form.model);
      setForm(EMPTY);
      setEditingId(null);
      load(search);
    } catch (err) {
      setMessage("Erro ao salvar: " + (err.response?.data?.error || err.message));
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
      <h1>Cadastro de Sapatos</h1>
      {message && <p className="flash">{message}</p>}

      <form onSubmit={onSubmit}>
        <input name="brand" placeholder="Marca" value={form.brand} onChange={onChange} required />
        <input name="model" placeholder="Modelo" value={form.model} onChange={onChange} required />
        <input name="size" type="number" placeholder="Tamanho" value={form.size} onChange={onChange} required />
        <input name="color" placeholder="Cor" value={form.color} onChange={onChange} required />
        <input name="price" placeholder="Preço" value={form.price} onChange={onChange} required />
        <input name="stock" type="number" min="0" placeholder="Estoque" value={form.stock} onChange={onChange} required />
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
          <p>
            Resultados para: <b>{search}</b>
          </p>
        )}
      </div>

      <table>
        <thead>
          <tr>
            <th>ID</th><th>Marca</th><th>Modelo</th><th>Tamanho</th><th>Cor</th><th>Preço</th><th>Estoque</th><th>Ações</th>
          </tr>
        </thead>
        <tbody>
          {shoes.map((s) => (
            <tr key={s.id}>
              <td>{s.id}</td>
              <td>{s.brand}</td>
              <td>{s.model}</td>
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
