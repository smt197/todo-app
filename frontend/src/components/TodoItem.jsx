import React, { useState } from 'react';
import './TodoItem.css';

function TodoItem({ todo, onToggle, onUpdate, onDelete }) {
  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(todo.title);
  const [editDescription, setEditDescription] = useState(todo.description || '');
  const [isUpdating, setIsUpdating] = useState(false);

  const handleToggle = () => {
    onToggle(todo.id);
  };

  const handleDelete = async () => {
    if (window.confirm('Voulez-vous vraiment supprimer cette tâche ?')) {
      await onDelete(todo.id);
    }
  };

  const handleEdit = () => {
    setIsEditing(true);
    setEditTitle(todo.title);
    setEditDescription(todo.description || '');
  };

  const handleSave = async () => {
    if (!editTitle.trim()) {
      alert('Le titre est requis');
      return;
    }

    setIsUpdating(true);
    const result = await onUpdate(todo.id, {
      ...todo,
      title: editTitle,
      description: editDescription
    });
    setIsUpdating(false);

    if (result.success) {
      setIsEditing(false);
    } else {
      alert(result.error || 'Erreur lors de la mise à jour');
    }
  };

  const handleCancel = () => {
    setIsEditing(false);
  };

  if (isEditing) {
    return (
      <div className="todo-item editing">
        <input
          type="text"
          value={editTitle}
          onChange={(e) => setEditTitle(e.target.value)}
          placeholder="Titre"
        />
        <textarea
          value={editDescription}
          onChange={(e) => setEditDescription(e.target.value)}
          placeholder="Description"
          rows="2"
        />
        <div className="todo-actions">
          <button onClick={handleSave} disabled={isUpdating}>
            {isUpdating ? 'Sauvegarde...' : '💾 Sauvegarder'}
          </button>
          <button onClick={handleCancel}>❌ Annuler</button>
        </div>
      </div>
    );
  }

  return (
    <div className={`todo-item ${todo.completed ? 'completed' : ''}`}>
      <div className="todo-content">
        <input
          type="checkbox"
          checked={todo.completed}
          onChange={handleToggle}
          className="todo-checkbox"
        />
        <div className="todo-text">
          <h3>{todo.title}</h3>
          {todo.description && <p>{todo.description}</p>}
        </div>
      </div>
      <div className="todo-actions">
        <button onClick={handleEdit} className="edit-btn">✏️</button>
        <button onClick={handleDelete} className="delete-btn">🗑️</button>
      </div>
    </div>
  );
}

export default TodoItem;