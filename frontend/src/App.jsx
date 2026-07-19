import React, { useState, useEffect } from 'react';
import axios from 'axios';
import TodoForm from './components/TodoForm';
import TodoList from './components/TodoList';
import './App.css';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

function App() {
  const [todos, setTodos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Charger les tâches au démarrage
  useEffect(() => {
    fetchTodos();
  }, []);

  const fetchTodos = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/todos`);
      setTodos(response.data);
      setError(null);
    } catch (err) {
      setError('Erreur lors du chargement des tâches');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const addTodo = async (newTodo) => {
    try {
      const response = await axios.post(`${API_URL}/todos`, newTodo);
      setTodos([response.data, ...todos]);
      return { success: true };
    } catch (err) {
      console.error(err);
      return { success: false, error: 'Erreur lors de la création' };
    }
  };

  const updateTodo = async (id, updates) => {
    try {
      const response = await axios.put(`${API_URL}/todos/${id}`, updates);
      setTodos(todos.map(todo => todo.id === id ? response.data : todo));
      return { success: true };
    } catch (err) {
      console.error(err);
      return { success: false, error: 'Erreur lors de la mise à jour' };
    }
  };

  const deleteTodo = async (id) => {
    try {
      await axios.delete(`${API_URL}/todos/${id}`);
      setTodos(todos.filter(todo => todo.id !== id));
      return { success: true };
    } catch (err) {
      console.error(err);
      return { success: false, error: 'Erreur lors de la suppression' };
    }
  };

  const toggleTodo = async (id) => {
    const todo = todos.find(t => t.id === id);
    if (todo) {
      await updateTodo(id, { 
        ...todo, 
        completed: !todo.completed 
      });
    }
  };

  return (
    <div className="app">
      <h1>📝 Todo List</h1>
      
      <div className="container">
        <TodoForm onAdd={addTodo} />
        
        {loading && <p className="loading">Chargement...</p>}
        
        {error && <p className="error">{error}</p>}
        
        {!loading && !error && (
          <TodoList 
            todos={todos}
            onToggle={toggleTodo}
            onUpdate={updateTodo}
            onDelete={deleteTodo}
          />
        )}
        
        {!loading && !error && todos.length === 0 && (
          <p className="empty">Aucune tâche pour le moment</p>
        )}
      </div>
    </div>
  );
}

export default App;