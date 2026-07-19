import React, { useState } from 'react';
import './TodoForm.css';

function TodoForm({ onAdd }) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!title.trim()) {
      alert('Veuillez entrer un titre');
      return;
    }

    setIsSubmitting(true);
    const result = await onAdd({ title, description });
    setIsSubmitting(false);

    if (result.success) {
      setTitle('');
      setDescription('');
    } else {
      alert(result.error || 'Erreur lors de la création');
    }
  };

  return (
    <form className="todo-form" onSubmit={handleSubmit}>
      <div className="form-group">
        <input
          type="text"
          placeholder="Titre de la tâche"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          disabled={isSubmitting}
        />
      </div>
      <div className="form-group">
        <textarea
          placeholder="Description (optionnelle)"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          disabled={isSubmitting}
          rows="3"
        />
      </div>
      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Ajout...' : 'Ajouter la tâche'}
      </button>
    </form>
  );
}

export default TodoForm;